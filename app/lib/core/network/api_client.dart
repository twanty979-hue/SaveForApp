import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class ApiClient {
  // ตรวจสอบและดึงค่า API_BASE_URL จาก .env หรือใช้ IP คอมพิวเตอร์จริงของผู้ใช้เป็นค่าสำรองตรง
  String get _baseUrl {
    if (dotenv.isInitialized &&
        dotenv.env['API_BASE_URL'] != null &&
        dotenv.env['API_BASE_URL']!.isNotEmpty) {
      return '${dotenv.env['API_BASE_URL']}/api/v1';
    }
    // ใช้ไอพีเครื่องของนาย (192.168.0.103) เป็นค่าเริ่มต้นสำรองทันที เพื่อให้แอปมือถือเชื่อมเข้าคอมได้แม้ติดขัดเรื่องโหลด .env จากแอสเซ็ต
    return 'http://192.168.0.103:8080/api/v1';
  }

  Future<http.Response> get(String path, {Map<String, String>? headers}) async {
    final url = Uri.parse('$_baseUrl$path');
    return await http.get(url, headers: headers);
  }

  Future<http.Response> post(String path, {Map<String, String>? headers, dynamic body}) async {
    final url = Uri.parse('$_baseUrl$path');
    final encodedBody = body != null ? jsonEncode(body) : null;
    final defaultHeaders = {
      'Content-Type': 'application/json',
      ...?headers,
    };
    return await http.post(url, headers: defaultHeaders, body: encodedBody);
  }

  Future<http.Response> delete(String path, {Map<String, String>? headers}) async {
    final url = Uri.parse('$_baseUrl$path');
    final defaultHeaders = {
      'Content-Type': 'application/json',
      ...?headers,
    };
    return await http.delete(url, headers: defaultHeaders);
  }

  Future<http.Response> patch(String path, {Map<String, String>? headers, dynamic body}) async {
    final url = Uri.parse('$_baseUrl$path');
    final encodedBody = body != null ? jsonEncode(body) : null;
    final defaultHeaders = {
      'Content-Type': 'application/json',
      ...?headers,
    };
    return await http.patch(url, headers: defaultHeaders, body: encodedBody);
  }

  Future<http.Response> put(String path, {Map<String, String>? headers, dynamic body}) async {
    final url = Uri.parse('$_baseUrl$path');
    final encodedBody = body != null ? jsonEncode(body) : null;
    final defaultHeaders = {
      'Content-Type': 'application/json',
      ...?headers,
    };
    return await http.put(url, headers: defaultHeaders, body: encodedBody);
  }
}
