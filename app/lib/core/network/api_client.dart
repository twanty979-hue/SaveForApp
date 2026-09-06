import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../../features/auth/domain/auth_session.dart';

class ApiClient {
  static Future<bool>? _refreshInFlight;
  static final Map<String, _CachedResponse> _getCache = {};
  static final Map<String, Future<http.Response>> _getInFlight = {};

  // ใช้ค่า API_BASE_URL จาก .env และใช้ Render เป็นค่าเริ่มต้นสำหรับ release
  String get _baseUrl {
    if (dotenv.isInitialized &&
        dotenv.env['API_BASE_URL'] != null &&
        dotenv.env['API_BASE_URL']!.isNotEmpty) {
      return '${dotenv.env['API_BASE_URL']}/api/v1';
    }
    // fallback นี้ช่วยให้ build จาก CI ที่ไม่มีไฟล์ .env ยังเชื่อมต่อ production API ได้
    return 'https://saveforapp.onrender.com/api/v1';
  }

  String absoluteUrl(String path) {
    if (path.startsWith('https://') || path.startsWith('http://')) return path;
    return '$_baseUrl$path';
  }

  Map<String, String> get authHeaders => _headers(null);

  Map<String, String> imageHeaders(String url) {
    return url.startsWith(_baseUrl) ? authHeaders : const {};
  }

  Map<String, String> _headers(Map<String, String>? headers) {
    return {
      if (AuthSession.accessToken?.isNotEmpty == true)
        'Authorization': 'Bearer ${AuthSession.accessToken}',
      ...?headers,
    };
  }

  Future<http.Response> _withAuthRetry(
    String path,
    Future<http.Response> Function() request,
  ) async {
    http.Response? response;
    for (int attempt = 0; attempt < 3; attempt++) {
      try {
        response = await request().timeout(const Duration(seconds: 15));
        break;
      } catch (e) {
        if (attempt == 2) {
          return http.Response(
            jsonEncode({'error': 'Network connection issue: $e'}),
            503,
            headers: {'content-type': 'application/json'},
          );
        }
        await Future.delayed(Duration(milliseconds: 400 * (attempt + 1)));
      }
    }

    if (response == null) {
      return http.Response(
        jsonEncode({'error': 'No response from server'}),
        503,
        headers: {'content-type': 'application/json'},
      );
    }

    if (response.statusCode != 401 ||
        path.startsWith('/auth/') ||
        AuthSession.refreshToken?.isNotEmpty != true) {
      return response;
    }

    if (await _refreshSession()) {
      try {
        return await request().timeout(const Duration(seconds: 15));
      } catch (_) {
        return response;
      }
    }
    return response;
  }

  Future<bool> _refreshSession() async {
    final running = _refreshInFlight;
    if (running != null) return running;

    final operation = _performRefresh();
    _refreshInFlight = operation;
    try {
      return await operation;
    } finally {
      if (identical(_refreshInFlight, operation)) {
        _refreshInFlight = null;
      }
    }
  }

  Future<bool> _performRefresh() async {
    final refreshToken = AuthSession.refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) return false;
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh_token': refreshToken}),
      );
      if (response.statusCode != 200) return false;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final access = data['access_token']?.toString();
      final refreshed = data['refresh_token']?.toString();
      if (access == null ||
          access.isEmpty ||
          refreshed == null ||
          refreshed.isEmpty) {
        return false;
      }
      await AuthSession.updateTokens(access: access, refresh: refreshed);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<http.Response> get(
    String path, {
    Map<String, String>? headers,
    Duration cacheDuration = const Duration(seconds: 30),
    bool forceRefresh = false,
  }) async {
    final cacheKey = '${AuthSession.userId ?? 'guest'}:$path';
    final cached = _getCache[cacheKey];
    if (!forceRefresh &&
        cached != null &&
        DateTime.now().difference(cached.savedAt) < cacheDuration) {
      return cached.response;
    }
    final running = _getInFlight[cacheKey];
    if (running != null) return running;

    final operation = _performGet(path, headers, cacheKey);
    _getInFlight[cacheKey] = operation;
    try {
      return await operation;
    } finally {
      _getInFlight.remove(cacheKey);
    }
  }

  Future<http.Response> _performGet(
    String path,
    Map<String, String>? headers,
    String cacheKey,
  ) async {
    final url = Uri.parse('$_baseUrl$path');
    final response = await _withAuthRetry(
      path,
      () => http.get(url, headers: _headers(headers)),
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      _getCache[cacheKey] = _CachedResponse(response, DateTime.now());
    }
    return response;
  }

  Future<void> preloadCoreData(String userId) async {
    try {
      await Future.wait([
        get('/transactions?user_id=eq.$userId'),
        get('/dreams?user_id=eq.$userId'),
        get('/recurring/expenses?user_id=eq.$userId'),
        get('/recurring/sources?user_id=eq.$userId'),
        get('/profile?id=eq.$userId&select=*'),
        get('/profile/avatar', cacheDuration: const Duration(minutes: 5)),
      ]);
    } catch (_) {
      // Ignore network / handshake / cold-start exceptions so startup is never blocked
    }
  }

  static void clearCache() {
    _getCache.clear();
  }

  Future<http.Response> post(
    String path, {
    Map<String, String>? headers,
    dynamic body,
  }) async {
    final url = Uri.parse('$_baseUrl$path');
    final encodedBody = body != null ? jsonEncode(body) : null;
    final response = await _withAuthRetry(
      path,
      () => http.post(
        url,
        headers: {'Content-Type': 'application/json', ..._headers(headers)},
        body: encodedBody,
      ),
    );
    if (response.statusCode >= 200 && response.statusCode < 300) clearCache();
    return response;
  }

  Future<http.Response> delete(
    String path, {
    Map<String, String>? headers,
  }) async {
    final url = Uri.parse('$_baseUrl$path');
    final response = await _withAuthRetry(
      path,
      () => http.delete(
        url,
        headers: {'Content-Type': 'application/json', ..._headers(headers)},
      ),
    );
    if (response.statusCode >= 200 && response.statusCode < 300) clearCache();
    return response;
  }

  Future<http.Response> patch(
    String path, {
    Map<String, String>? headers,
    dynamic body,
  }) async {
    final url = Uri.parse('$_baseUrl$path');
    final encodedBody = body != null ? jsonEncode(body) : null;
    final response = await _withAuthRetry(
      path,
      () => http.patch(
        url,
        headers: {'Content-Type': 'application/json', ..._headers(headers)},
        body: encodedBody,
      ),
    );
    if (response.statusCode >= 200 && response.statusCode < 300) clearCache();
    return response;
  }

  Future<http.Response> put(
    String path, {
    Map<String, String>? headers,
    dynamic body,
  }) async {
    final url = Uri.parse('$_baseUrl$path');
    final encodedBody = body != null ? jsonEncode(body) : null;
    final response = await _withAuthRetry(
      path,
      () => http.put(
        url,
        headers: {'Content-Type': 'application/json', ..._headers(headers)},
        body: encodedBody,
      ),
    );
    if (response.statusCode >= 200 && response.statusCode < 300) clearCache();
    return response;
  }

  Future<http.Response> multipartPost(
    String path, {
    required String fieldName,
    required String filename,
    required List<int> bytes,
  }) async {
    Future<http.Response> send() async {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl$path'),
      );
      request.headers.addAll(_headers(null));
      request.files.add(
        http.MultipartFile.fromBytes(fieldName, bytes, filename: filename),
      );
      return http.Response.fromStream(await request.send());
    }

    final response = await _withAuthRetry(path, send);
    if (response.statusCode >= 200 && response.statusCode < 300) clearCache();
    return response;
  }
}

class _CachedResponse {
  const _CachedResponse(this.response, this.savedAt);

  final http.Response response;
  final DateTime savedAt;
}
