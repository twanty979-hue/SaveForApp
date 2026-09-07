import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'slip_parser_service.dart';

class SlipScannerBridge {
  SlipScannerBridge._() {
    refreshUnscannedCount();
  }
  static final SlipScannerBridge instance = SlipScannerBridge._();

  static const MethodChannel _channel = MethodChannel('com.savefor.app/slip_scanner');
  static const String _prefSavedSlipKeys = 'saved_slip_dedup_keys';
  static const String _prefLastScanTimestamp = 'last_slip_scan_timestamp';

  /// จำนวนสลิปที่ตรวจพบและยังไม่ได้บันทึก (สำหรับแสดง Badge บนปุ่มสแกน)
  final ValueNotifier<int> unscannedCount = ValueNotifier<int>(0);

  bool get isSupported => !kIsWeb && (Platform.isIOS || Platform.isAndroid);

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

  /// ดึงรายชื่ออัลบั้มธนาคารที่ตรวจพบบนเครื่อง (เช่น K PLUS, SCB EASY)
  Future<List<Map<String, dynamic>>> getAvailableBankAlbums() async {
    if (!isSupported) return [];
    try {
      final dynamic result = await _channel.invokeMethod('getAvailableBankAlbums');
      if (result is List) {
        return result.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('Error getting bank albums: $e');
      return [];
    }
  }

  /// สแกนหาภาพสลิปย้อนหลังจากอัลบั้มรูปภาพ
  /// [daysBack]: จำนวนวันที่ต้องการย้อนหลัง (0 หมายถึงใช้ lastScanTimestamp)
  /// [forceAll]: บังคับสแกนทั้งหมดโดยไม่สน lastScanTimestamp
  /// [albumName]: ระบุชื่ออัลบั้มที่ต้องการสแกน (ค่าเริ่มต้น: 'ALL_BANKS' สแกนทุกธนาคาร K PLUS, SCB, Krungsri, TrueMoney)
  /// ล้างประวัติและตัวแปรจำลองทั้งหมด (ไม่ใช้ Mockup ใดๆ อีกต่อไป ใช้งานข้อมูลจริง 100%)

  /// ตรวจสอบว่าเป็นเครื่อง Simulator หรือไม่
  Future<bool> isSimulator() async {
    // 1. ตรวจสอบจาก File System Path (บน iOS Simulator ทุก Path ใน Sandbox มีคำว่า CoreSimulator เสมอ 100%)
    try {
      if (Directory.systemTemp.path.contains('CoreSimulator')) {
        return true;
      }
    } catch (_) {}

    // 2. ตรวจสอบจาก Environment Variables ของ iOS Simulator ใน Dart โดยตรง
    if (Platform.environment.containsKey('SIMULATOR_DEVICE_NAME') ||
        Platform.environment.containsKey('SIMULATOR_ROOT') ||
        Platform.environment.containsKey('SIMULATOR_UDID') ||
        Platform.environment.containsKey('IPHONE_SIMULATOR_ROOT')) {
      return true;
    }

    // 3. หากไม่ใช่ iOS จริง (เช่น macOS, Windows, Web)
    if (!isSupported) return true;

    // 4. Fallback ผ่าน MethodChannel บน Native iOS
    try {
      final res = await _channel.invokeMethod<bool>('isSimulator');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// สแกนหาภาพสลิปย้อนหลังจากอัลบั้มรูปภาพ
  /// [daysBack]: จำนวนวันที่ต้องการย้อนหลัง (สูงสุด 30 วัน)
  /// [startDate]: วันที่เริ่มต้นที่ต้องการสแกนย้อนหลัง (ต้องไม่เกิน 30 วัน)
  /// [endDate]: วันที่สิ้นสุด (ดีฟอลต์คือปัจจุบัน)
  /// [forceAll]: บังคับสแกนทั้งหมดโดยไม่สน lastScanTimestamp
  /// [albumName]: ระบุชื่ออัลบั้มที่ต้องการสแกน (ค่าเริ่มต้น: 'ALL_BANKS' สแกน 4 ธนาคาร)
  Future<List<ParsedSlip>> scanRecentSlips({
    int daysBack = 30,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 50,
    bool forceAll = false,
    String? albumName = 'ALL_BANKS',
  }) async {
    if (!isSupported) return [];

    try {
      final prefs = await SharedPreferences.getInstance();
      final lastScan = forceAll ? 0.0 : (prefs.getDouble(_prefLastScanTimestamp) ?? 0.0);

      // คำนวณวันย้อนหลัง (จำกัดไม่ให้เกิน 30 วันตามเงื่อนไขผู้ใช้)
      int effectiveDaysBack = daysBack.clamp(1, 30);
      DateTime? effectiveStartDate = startDate;
      if (effectiveStartDate != null) {
        final diff = DateTime.now().difference(effectiveStartDate).inDays + 1;
        effectiveDaysBack = diff.clamp(1, 30);
      } else {
        effectiveStartDate = DateTime.now().subtract(Duration(days: effectiveDaysBack));
      }

      final startMs = effectiveStartDate.millisecondsSinceEpoch.toDouble();
      final endMs = (endDate ?? DateTime.now()).millisecondsSinceEpoch.toDouble();

      final dynamic result = await _channel.invokeMethod('scanRecentSlips', {
        'daysBack': effectiveDaysBack,
        'startTimestamp': startMs,
        'endTimestamp': endMs,
        'limit': limit,
        'lastScanTimestamp': lastScan,
        'albumName': albumName,
      });

      if (result is! List) return [];
      debugPrint('[SlipScannerBridge] Received ${result.length} candidate slips from native iOS');

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
        final imagePath = item['imagePath']?.toString();
        final albumName = item['albumName']?.toString();

        final parsed = SlipParserService.instance.parse(
          id: id,
          lines: rawLines,
          fullText: fullText,
          fallbackDate: fallbackDate,
          imagePath: imagePath,
          albumName: albumName,
        );

        if (parsed != null) {
          // ตรวจสอบว่าวันที่ของสลิปต้องไม่อยู่ก่อน startDate
          if (effectiveStartDate != null) {
            final cutoff = DateTime(effectiveStartDate.year, effectiveStartDate.month, effectiveStartDate.day);
            if (parsed.date.isBefore(cutoff)) {
              debugPrint('[SlipScannerBridge] Slip ${parsed.id} skipped: date ${parsed.date} is before cutoff $cutoff');
              continue;
            }
          }

          // คัดกรองรายการที่เคยบันทึกไปแล้วออก (หาก forceAll เป็นจริง ให้แสดงทั้งหมดเพื่อทดสอบ)
          if (forceAll || !savedKeys.contains(parsed.deduplicationKey)) {
            parsedList.add(parsed);
          } else {
            debugPrint('[SlipScannerBridge] Slip ${parsed.id} skipped (already saved: ${parsed.deduplicationKey})');
          }
        }
      }

      debugPrint('[SlipScannerBridge] Successfully parsed ${parsedList.length} valid slips');
      return parsedList;
    } catch (e) {
      debugPrint('Error scanning recent slips on device: $e');
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
      final imagePath = result['imagePath']?.toString() ?? filePath;
      final albumName = result['albumName']?.toString() ?? 'รูปภาพที่เลือก';

      return SlipParserService.instance.parse(
        id: filePath,
        lines: rawLines,
        fullText: fullText,
        fallbackDate: DateTime.now(),
        imagePath: imagePath,
        albumName: albumName,
      );
    } catch (e) {
      debugPrint('Error scanning single slip: $e');
      return null;
    }
  }

  static const String _prefSlipHistoryReset = 'slip_history_was_reset';
  bool _historyWasReset = false;

  /// รีเซ็ตประวัติการสแกนทั้งหมด (ล้างทั้งแคชคีย์ และ timestamp เพื่อให้ตรวจจับสลิปที่มีอยู่ใหม่ได้ทั้งหมด)
  Future<void> resetScanHistory() async {
    _historyWasReset = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefSavedSlipKeys);
    await prefs.remove(_prefLastScanTimestamp);
    await prefs.setBool(_prefSlipHistoryReset, true);

    unscannedCount.value = 0;
    await refreshUnscannedCount();
  }

  /// บันทึกคีย์สลิปที่ยืนยันแล้วลง SharedPreferences เพื่อไม่ให้อ่านซ้ำ
  Future<void> markSlipsAsSaved(List<ParsedSlip> slips) async {
    try {
      _historyWasReset = false;
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefSlipHistoryReset);
      final savedKeys = prefs.getStringList(_prefSavedSlipKeys)?.toSet() ?? <String>{};
      for (var s in slips) {
        savedKeys.add(s.deduplicationKey);
      }
      await prefs.setStringList(_prefSavedSlipKeys, savedKeys.toList());
      // อัปเดต timestamp ล่าสุดหลังจากบันทึกแล้ว
      await prefs.setDouble(_prefLastScanTimestamp, DateTime.now().millisecondsSinceEpoch / 1000.0);
      await refreshUnscannedCount();
    } catch (e) {
      debugPrint('Error saving slip dedup keys: $e');
    }
  }

  /// ซิงก์ประวัติสลิปที่เคยบันทึกไว้จากเซิร์ฟเวอร์ (รองรับกรณีย้ายเครื่อง หรือลบแอพแล้วโหลดใหม่)
  Future<int> syncSavedSlipsFromServer({
    required String userId,
    required dynamic apiClient,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (_historyWasReset || (prefs.getBool(_prefSlipHistoryReset) ?? false)) {
      return 0;
    }
    try {
      final response = await apiClient.get(
        '/transactions?user_id=eq.$userId&select=note,amount,transaction_date',
      );
      if (response.statusCode != 200) return 0;
      final dynamic data = jsonDecode(response.body);
      if (data is! List) return 0;

      final savedKeys = prefs.getStringList(_prefSavedSlipKeys)?.toSet() ?? <String>{};
      int restored = 0;

      for (var row in data) {
        if (row is! Map) continue;
        final note = row['note']?.toString() ?? '';
        final bankStr = row['bank']?.toString();
        final bank = (bankStr != null && bankStr.isNotEmpty)
            ? BankType.values.cast<BankType?>().firstWhere((b) => b?.name == bankStr, orElse: () => null)
            : BankType.detectFromText(note);
        if (bank == null) continue;

        // 1. ตรวจหา Ref number จากคอลัมน์ reference_no หรือจาก note เช่น [Ref:01424518294958102]
        String? refNo = row['reference_no']?.toString();
        if (refNo == null || refNo.isEmpty) {
          final refMatch = RegExp(r'\[Ref:([a-zA-Z0-9]+)\]').firstMatch(note);
          if (refMatch != null && refMatch.group(1) != null) {
            refNo = refMatch.group(1)!;
          }
        }
        if (refNo != null && refNo.isNotEmpty) {
          final key = '${bank.name}_$refNo';
          if (savedKeys.add(key)) {
            restored++;
          }
          continue;
        }

        // 2. Fallback: กรณีสลิปรุ่นเก่าที่ไม่มี [Ref:...] ให้ดึงจาก ยอดเงินและวันเวลา
        final amount = (row['amount'] as num?)?.toDouble() ?? 0.0;
        final dateStr = row['transaction_date']?.toString();
        final date = dateStr != null ? DateTime.tryParse(dateStr) : null;
        if (date != null) {
          final key =
              '${bank.name}_${amount.toStringAsFixed(2)}_${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}_${date.hour}${date.minute}';
          if (savedKeys.add(key)) {
            restored++;
          }
        }
      }

      if (restored > 0) {
        await prefs.setStringList(_prefSavedSlipKeys, savedKeys.toList());
        await refreshUnscannedCount();
      }
      return restored;
    } catch (e) {
      debugPrint('Error syncing saved slips from server: $e');
      return 0;
    }
  }

  /// รีเฟรชและนับจำนวนสลิปที่ยังไม่ได้สแกน/ยังไม่ได้บันทึก
  Future<int> refreshUnscannedCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedKeys = prefs.getStringList(_prefSavedSlipKeys)?.toSet() ?? <String>{};

      if (!isSupported) {
        unscannedCount.value = 0;
        return 0;
      }

      final perm = await checkPermission();
      if (perm != 'authorized' && perm != 'limited') {
        unscannedCount.value = 0;
        return 0;
      }

      final isReset = _historyWasReset || (prefs.getBool(_prefSlipHistoryReset) ?? false);
      final lastScan = isReset ? 0.0 : (prefs.getDouble(_prefLastScanTimestamp) ?? 0.0);
      final daysBack = isReset ? 0 : 30;

      final dynamic result = await _channel.invokeMethod('scanRecentSlips', {
        'daysBack': daysBack,
        'limit': 50,
        'lastScanTimestamp': lastScan,
        'albumName': 'ALL_BANKS',
      });

      if (result is! List) {
        unscannedCount.value = 0;
        return 0;
      }

      int count = 0;
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

        if (parsed != null && !savedKeys.contains(parsed.deduplicationKey)) {
          count++;
        }
      }

      unscannedCount.value = count;
      return count;
    } catch (e) {
      debugPrint('Error refreshing unscanned count: $e');
      unscannedCount.value = 0;
      return 0;
    }
  }
}
