import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app/core/services/slip_cloud_service.dart';
import 'package:app/core/settings/app_settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('SlipCloudService Tests', () {
    test('compressToWebP converts large image to lightweight WebP with RIFF header', () async {
      // สร้างภาพทดสอบขนาด 1200x1600 (ใหญ่กว่า 800px)
      final testImage = img.Image(width: 1200, height: 1600);
      img.fill(testImage, color: img.ColorRgb8(240, 240, 240));
      img.drawLine(testImage, x1: 50, y1: 50, x2: 1150, y2: 1550, color: img.ColorRgb8(20, 40, 80));

      final pngBytes = Uint8List.fromList(img.encodePng(testImage));
      expect(pngBytes.isNotEmpty, isTrue);

      // บีบอัดเป็น WebP
      final webpBytes = await SlipCloudService.instance.compressToWebP(pngBytes);
      expect(webpBytes.isNotEmpty, isTrue);

      // ตรวจสอบ WebP header (RIFF .... WEBP)
      final riffHeader = String.fromCharCodes(webpBytes.sublist(0, 4));
      final webpHeader = String.fromCharCodes(webpBytes.sublist(8, 12));
      expect(riffHeader, equals('RIFF'));
      expect(webpHeader, equals('WEBP'));

      // ตรวจสอบว่าภาพถูก resize ความกว้างเหลือไม่เกิน 800px
      final decodedWebp = img.decodeImage(webpBytes);
      expect(decodedWebp, isNotNull);
      expect(decodedWebp!.width, lessThanOrEqualTo(800));
    });

    test('AppSettings backupSlipsToCloud defaults to false and persists updates', () async {
      expect(AppSettings.backupSlipsToCloud.value, isFalse);

      await AppSettings.setBackupSlipsToCloud(true);
      expect(AppSettings.backupSlipsToCloud.value, isTrue);

      await AppSettings.setBackupSlipsToCloud(false);
      expect(AppSettings.backupSlipsToCloud.value, isFalse);
    });
  });
}
