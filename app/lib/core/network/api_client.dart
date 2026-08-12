import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../../features/auth/domain/auth_session.dart';

class ApiClient {
  static Future<bool>? _refreshInFlight;
  static final Map<String, _CachedResponse> _getCache = {};
  static final Map<String, Future<http.Response>> _getInFlight = {};

  // ตรวจสอบและดึงค่า API_BASE_URL จาก .env หรือใช้ IP คอมพิวเตอร์จริงของผู้ใช้เป็นค่าสำรองตรง
  String get _baseUrl {
    // หากรันอยู่บน Web และเล่นผ่าน localhost ให้ใช้หลังบ้านเป็น localhost:8080 ทันที ป้องกันปัญหา IP เครื่องคอมพิวเตอร์เปลี่ยนในวง Wi-Fi
    if (kIsWeb && Uri.base.host == 'localhost') {
      return 'http://localhost:8080/api/v1';
    }

    if (dotenv.isInitialized &&
        dotenv.env['API_BASE_URL'] != null &&
        dotenv.env['API_BASE_URL']!.isNotEmpty) {
      return '${dotenv.env['API_BASE_URL']}/api/v1';
    }
    // ใช้ไอพีเครื่องของนาย (192.168.0.103) เป็นค่าเริ่มต้นสำรองทันที เพื่อให้แอปมือถือเชื่อมเข้าคอมได้แม้ติดขัดเรื่องโหลด .env จากแอสเซ็ต
    return 'http://192.168.0.103:8080/api/v1';
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
    var response = await request();
    if (response.statusCode != 401 ||
        path.startsWith('/auth/') ||
        AuthSession.refreshToken?.isNotEmpty != true) {
      return response;
    }

    if (await _refreshSession()) {
      response = await request();
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
    await Future.wait([
      get('/transactions?user_id=eq.$userId'),
      get('/dreams?user_id=eq.$userId'),
      get('/recurring/expenses?user_id=eq.$userId'),
      get('/recurring/sources?user_id=eq.$userId'),
      get('/profile?id=eq.$userId&select=*'),
      get('/profile/avatar', cacheDuration: const Duration(minutes: 5)),
    ]);
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
