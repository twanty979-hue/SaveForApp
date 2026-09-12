import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image/image.dart' as img;

import '../network/api_client.dart';
import '../settings/app_settings.dart';
import '../../features/auth/domain/auth_session.dart';

// ฟังก์ชันประมวลผลการบีบอัดรูปภาพเป็น WebP ใน Background Isolate ไม่หน่วง UI
Uint8List _compressToWebPIsolate(Uint8List rawBytes) {
  try {
    final decoded = img.decodeImage(rawBytes);
    if (decoded == null) return rawBytes;

    // สลิปธนาคารกำหนดความกว้างสูงสุด 800px อ่านตัวหนังสือและยอดเงินคมชัด 100%
    // แต่ช่วยลดขนาดไฟล์จากหลาย MB เหลือเพียง 30 - 60 KB เท่านั้น
    final resized = decoded.width > 800
        ? img.copyResize(
            decoded,
            width: 800,
            interpolation: img.Interpolation.linear,
          )
        : decoded;

    final webp = img.encodeWebP(resized);
    return Uint8List.fromList(webp);
  } catch (e) {
    debugPrint('WebP compression error in isolate: $e');
    return rawBytes;
  }
}

class SlipCloudService {
  SlipCloudService._();
  static final SlipCloudService instance = SlipCloudService._();

  final ApiClient _apiClient = ApiClient();

  /// บีบอัดภาพเป็น WebP คุณภาพสูงแต่เบาที่สุดผ่าน Background Isolate
  Future<Uint8List> compressToWebP(Uint8List rawBytes) async {
    return compute(_compressToWebPIsolate, rawBytes);
  }

  /// อัปโหลดไฟล์สลิป WebP ขึ้น Cloudflare R2 แยกตาม User ID
  Future<String?> uploadSlip({
    required String slipId,
    required Uint8List webpBytes,
  }) async {
    if (!AuthSession.isLoggedIn) return null;

    try {
      final uploadUri = Uri.parse(_apiClient.absoluteUrl('/transactions/slip/upload'));
      final request = http.MultipartRequest('POST', uploadUri);

      // แนบ Bearer Token ตรวจสอบสิทธิ์ผู้ใช้
      request.headers.addAll(_apiClient.authHeaders);

      // ตั้งชื่อไฟล์ให้ปลอดภัย
      final cleanId = slipId.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
      final filename = '$cleanId.webp';

      request.fields['filename'] = filename;
      request.fields['slip_id'] = cleanId;

      request.files.add(
        http.MultipartFile.fromBytes(
          'slip',
          webpBytes,
          filename: filename,
          contentType: MediaType('image', 'webp'),
        ),
      );

      final streamedResponse = await request.send().timeout(const Duration(seconds: 25));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final cloudUrl = data['url']?.toString();
        debugPrint('Slip uploaded successfully: $cloudUrl (${webpBytes.lengthInBytes} bytes)');
        return cloudUrl;
      } else {
        debugPrint('Failed to upload slip to cloud: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('Error uploading slip image to cloud: $e');
      return null;
    }
  }

  /// ซิงค์อัปโหลดสลิปในเบื้องหลังเงียบๆ (Silent Background Sync)
  /// ทำงานเมื่อผู้ใช้เปิดสวิตช์ "สำรองรูปสลิปขึ้น Cloud" ไว้เท่านั้น
  Future<String?> silentUploadSlip({
    required String slipId,
    required String localPath,
  }) async {
    if (!AppSettings.backupSlipsToCloud.value) return null;
    if (!AuthSession.isLoggedIn) return null;

    final file = File(localPath);
    if (!file.existsSync()) return null;

    try {
      final rawBytes = await file.readAsBytes();
      if (rawBytes.isEmpty) return null;

      // บีบอัดเป็น WebP
      final webpBytes = await compressToWebP(rawBytes);

      // อัปโหลดขึ้น R2
      final cloudUrl = await uploadSlip(
        slipId: slipId,
        webpBytes: webpBytes,
      );

      return cloudUrl;
    } catch (e) {
      debugPrint('Silent slip upload error: $e');
      return null;
    }
  }
}
