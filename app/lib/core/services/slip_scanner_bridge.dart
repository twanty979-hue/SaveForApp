import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'slip_parser_service.dart';

class SlipScannerBridge {
  SlipScannerBridge._();
  static final SlipScannerBridge instance = SlipScannerBridge._();

  static const MethodChannel _channel = MethodChannel('com.savefor.app/slip_scanner');
  static const String _prefSavedSlipKeys = 'saved_slip_dedup_keys';
  static const String _prefLastScanTimestamp = 'last_slip_scan_timestamp';

  bool get isSupported => !kIsWeb && Platform.isIOS;

  /// ตรวจสอบสิทธิ์การเข้าถึง Photos
  Future<String> checkPermission() async {
    if (!isSupported) return 'unsupported';
    try {
      final result = await _channel.invokeMethod<String>('checkPermission');
      return result ?? 'unknown';
    } catch (e) {
      debugPrint('Error checking slip permission: $e');
      return 'error';
    }
  }

  /// ขอสิทธิ์การเข้าถึง Photos
  Future<String> requestPermission() async {
    if (!isSupported) return 'unsupported';
    try {
      final result = await _channel.invokeMethod<String>('requestPermission');
      return result ?? 'unknown';
    } catch (e) {
      debugPrint('Error requesting slip permission: $e');
      return 'error';
    }
  }

  /// สแกนหาภาพสลิปย้อนหลังจากอัลบั้มรูปภาพ
  /// [daysBack]: จำนวนวันที่ต้องการย้อนหลัง (0 หมายถึงใช้ lastScanTimestamp)
  /// [forceAll]: บังคับสแกนทั้งหมดโดยไม่สน lastScanTimestamp
  Future<List<ParsedSlip>> scanRecentSlips({
    int daysBack = 30,
    int limit = 60,
    bool forceAll = false,
  }) async {
    if (!isSupported) return [];

    try {
      final prefs = await SharedPreferences.getInstance();
      final lastScan = forceAll ? 0.0 : (prefs.getDouble(_prefLastScanTimestamp) ?? 0.0);

      final dynamic result = await _channel.invokeMethod('scanRecentSlips', {
        'daysBack': daysBack,
        'limit': limit,
        'lastScanTimestamp': lastScan,
      });

      if (result is! List) return [];

      final savedKeys = prefs.getStringList(_prefSavedSlipKeys)?.toSet() ?? <String>{};
      final List<ParsedSlip> parsedList = [];

      for (var item in result) {
        if (item is! Map) continue;
        final id = item['id']?.toString() ?? '';
        final creationMs = (item['creationDate'] as num?)?.toDouble() ?? 0.0;
        final fallbackDate = creationMs > 0
            ? DateTime.fromMillisecondsSinceEpoch(creationMs.toInt())
            : null;

        final rawLines = (item['lines'] as List?)?.map((e) => e.toString()).toList() ?? [];
        final fullText = item['fullText']?.toString() ?? '';

        final parsed = SlipParserService.instance.parse(
          id: id,
          lines: rawLines,
          fullText: fullText,
          fallbackDate: fallbackDate,
        );

        if (parsed != null) {
          // คัดกรองรายการที่เคยบันทึกไปแล้วออก
          if (!savedKeys.contains(parsed.deduplicationKey)) {
            parsedList.add(parsed);
          }
        }
      }

      // อัปเดต timestamp ล่าสุดไว้สำหรับครั้งต่อไป
      await prefs.setDouble(_prefLastScanTimestamp, DateTime.now().millisecondsSinceEpoch / 1000.0);

      return parsedList;
    } catch (e) {
      debugPrint('Error scanning recent slips: $e');
      return [];
    }
  }

  /// สแกนภาพเดี่ยวจาก Path (เช่น นำเข้าจาก ImagePicker)
  Future<ParsedSlip?> scanSingleImage(String filePath) async {
    if (!isSupported) return null;

    try {
      final dynamic result = await _channel.invokeMethod('scanSingleImage', {
        'path': filePath,
      });

      if (result is! Map) return null;

      final rawLines = (result['lines'] as List?)?.map((e) => e.toString()).toList() ?? [];
      final fullText = result['fullText']?.toString() ?? '';

      return SlipParserService.instance.parse(
        id: filePath,
        lines: rawLines,
        fullText: fullText,
        fallbackDate: DateTime.now(),
      );
    } catch (e) {
      debugPrint('Error scanning single slip: $e');
      return null;
    }
  }

  /// บันทึกคีย์สลิปที่ยืนยันแล้วลง SharedPreferences เพื่อไม่ให้อ่านซ้ำ
  Future<void> markSlipsAsSaved(List<ParsedSlip> slips) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedKeys = prefs.getStringList(_prefSavedSlipKeys)?.toSet() ?? <String>{};
      for (var s in slips) {
        savedKeys.add(s.deduplicationKey);
      }
      await prefs.setStringList(_prefSavedSlipKeys, savedKeys.toList());
    } catch (e) {
      debugPrint('Error saving slip dedup keys: $e');
    }
  }

  /// รีเซ็ตประวัติการสแกน (สำหรับกรณีผู้ใช้ต้องการเริ่มสแกนใหม่ทั้งหมด)
  Future<void> resetScanHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefSavedSlipKeys);
    await prefs.remove(_prefLastScanTimestamp);
  }
}
