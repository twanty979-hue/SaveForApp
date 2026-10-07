import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/bank_rule_model.dart';
import '../settings/app_settings.dart';
import 'slip_parser_service.dart';
export 'slip_parser_service.dart';

class SlipScannerBridge {
  final StreamController<ParsedSlip> _liveSlipStreamController = StreamController<ParsedSlip>.broadcast();
  Stream<ParsedSlip> get onLiveSlipDetected => _liveSlipStreamController.stream;

  final StreamController<Map<String, int>> _scanProgressStreamController = StreamController<Map<String, int>>.broadcast();
  Stream<Map<String, int>> get onScanProgress => _scanProgressStreamController.stream;

  DateTime? _activeScanStartDate;

  SlipScannerBridge._() {
    SlipParserService.loadLearnedOwnData();
    refreshUnscannedCount();
    _channel.setMethodCallHandler(_handleNativeMethodCall);
  }
  static final SlipScannerBridge instance = SlipScannerBridge._();

  static const MethodChannel _channel = MethodChannel('com.savefor.app/slip_scanner');
  static const String _prefSavedSlipKeys = 'saved_slip_dedup_keys';
  static const String _prefLastScanTimestamp = 'last_slip_scan_timestamp';

  Future<dynamic> _handleNativeMethodCall(MethodCall call) async {
    try {
      if (call.method == 'onSlipDetected') {
        final args = call.arguments;
        if (args is Map) {
          final prefs = await SharedPreferences.getInstance();
          final savedKeys = prefs.getStringList(_prefSavedSlipKeys)?.toSet() ?? <String>{};
          final parsed = parseRawSlipMap(
            args,
            effectiveStartDate: _activeScanStartDate,
            savedKeys: savedKeys,
          );
          if (parsed != null) {
            _liveSlipStreamController.add(parsed);
          }
        }
      } else if (call.method == 'onScanProgress') {
        final args = call.arguments;
        if (args is Map) {
          final cur = (args['current'] as num?)?.toInt() ?? 0;
          final tot = (args['total'] as num?)?.toInt() ?? 0;
          _scanProgressStreamController.add({'current': cur, 'total': tot});
        }
      }
    } catch (e) {
      debugPrint('[SlipScannerBridge] _handleNativeMethodCall error: $e');
    }
    return null;
  }

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

  /// อัปเดตรายชื่อธนาคารและคีย์เวิร์ดอัลบั้มไปยัง Native (iOS / Android)
  Future<bool> updateBankRules(List<BankRuleConfig> rules) async {
    if (!isSupported) return false;
    try {
      final payload = rules.map((r) => {
        'name': r.name,
        'appName': r.appName,
        'keywords': r.albumKeywords,
        'bankTag': '${r.name} ${r.appName}',
      }).toList();
      final res = await _channel.invokeMethod<bool>('updateBankRules', payload);
      return res ?? true;
    } catch (e) {
      debugPrint('Error updating bank rules: $e');
      return false;
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
  /// [daysBack]: จำนวนวันที่ต้องการย้อนหลัง (สูงสุด 365 วัน, หรือ 0 สำหรับทั้งหมด)
  /// [startDate]: วันที่เริ่มต้นที่ต้องการสแกนย้อนหลัง
  /// [endDate]: วันที่สิ้นสุด (ดีฟอลต์คือปัจจุบัน)
  /// [forceAll]: บังคับสแกนทั้งหมดโดยไม่สน lastScanTimestamp
  /// [albumName]: ระบุชื่ออัลบั้มที่ต้องการสแกน (ค่าเริ่มต้น: 'ALL_BANKS' สแกน 4 ธนาคาร)
  Future<List<ParsedSlip>> scanRecentSlips({
    int daysBack = 30,
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
    bool forceAll = false,
    String? albumName = 'ALL_BANKS',
  }) async {
    if (!isSupported) return [];
    try {
      await SlipParserService.loadLearnedOwnData();
      final prefs = await SharedPreferences.getInstance();
      final lastScan = forceAll ? 0.0 : (prefs.getDouble(_prefLastScanTimestamp) ?? 0.0);

      // คำนวณวันย้อนหลัง (ถ้าส่ง 0 หรือน้อยกว่า และไม่ระบุ startDate จะค้นหาทั้งหมดโดยไม่จำกัดวัน)
      final int effectiveDaysBack = (daysBack <= 0) ? 0 : daysBack.clamp(1, 365);
      final DateTime? effectiveStartDate;
      if (startDate != null) {
        effectiveStartDate = startDate;
      } else if (effectiveDaysBack > 0) {
        effectiveStartDate = DateTime.now().subtract(Duration(days: effectiveDaysBack));
      } else {
        effectiveStartDate = null;
      }

      // คำนวณขีดจำกัดการสแกนตามช่วงเวลา (หากสแกนหลายเดือน/1 ปี ให้รองรับได้สูงสุดถึง 1000 รูป)
      final int effectiveLimit = limit ?? (
        effectiveDaysBack >= 180 ? 1000 :
        effectiveDaysBack >= 90 ? 600 :
        effectiveDaysBack >= 30 ? 300 :
        effectiveDaysBack >= 7 ? 150 : 80
      );

      _activeScanStartDate = effectiveStartDate;
      final startMs = effectiveStartDate != null
          ? effectiveStartDate.millisecondsSinceEpoch.toDouble()
          : 0.0;
      final endMs = (endDate ?? DateTime.now()).millisecondsSinceEpoch.toDouble();

      final dynamic result = await _channel.invokeMethod('scanRecentSlips', {
        'daysBack': effectiveDaysBack,
        'startTimestamp': startMs,
        'endTimestamp': endMs,
        'limit': effectiveLimit,
        'lastScanTimestamp': lastScan,
        'albumName': albumName,
      });

      if (result is! List) return [];
      debugPrint('[SlipScannerBridge] Received ${result.length} candidate slips from native');

      final savedKeys = prefs.getStringList(_prefSavedSlipKeys)?.toSet() ?? <String>{};
      final List<ParsedSlip> parsedList = [];

      for (var item in result) {
        if (item is! Map) continue;
        final parsed = parseRawSlipMap(
          item,
          effectiveStartDate: effectiveStartDate,
          savedKeys: savedKeys,
        );
        if (parsed != null) {
          parsedList.add(parsed);
        }
      }

      debugPrint('[SlipScannerBridge] Successfully parsed ${parsedList.length} valid slips');
      return parsedList;
    } catch (e) {
      debugPrint('Error scanning recent slips on device: $e');
      return [];
    } finally {
      _activeScanStartDate = null;
    }
  }

  /// แปลงข้อมูล Raw Slip จาก Native เป็น ParsedSlip พร้อมตัวกรองความถูกต้อง
  ParsedSlip? parseRawSlipMap(
    Map<dynamic, dynamic> item, {
    DateTime? effectiveStartDate,
    Set<String>? savedKeys,
  }) {
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
      // ตรวจสอบว่าวันที่ของสลิปต้องไม่อยู่ก่อน startDate (เผื่อหย่อน 1 วันสำหรับ timezone)
      if (effectiveStartDate != null) {
        final cutoff = DateTime(effectiveStartDate.year, effectiveStartDate.month, effectiveStartDate.day)
            .subtract(const Duration(days: 1));
        if (parsed.date.isBefore(cutoff)) {
          debugPrint('[SlipScannerBridge] Slip ${parsed.id} skipped: date ${parsed.date} is before cutoff $cutoff');
          return null;
        }
      }

      // ตรวจสอบว่าธนาคารนี้ถูกเปิดใช้งานในหน้าตั้งค่าหรือไม่ (ผู้ใช้สามารถติ๊กเปิด/ปิดได้)
      if (!AppSettings.isAutoScanBankEnabled(parsed.bank.name)) {
        debugPrint('[SlipScannerBridge] Slip ${parsed.id} skipped (bank ${parsed.bank.name} is disabled by user)');
        return null;
      }

      // คัดกรองรายการที่เคยบันทึกไปแล้วออกอย่างเด็ดขาด (ห้ามอ่านสลิปซ้ำเด็ดขาด)
      if (savedKeys != null && _isSlipSaved(parsed, savedKeys)) {
        debugPrint('[SlipScannerBridge] Slip ${parsed.id} skipped (already saved: ${parsed.deduplicationKey})');
        return null;
      }
    }

    return parsed;
  }

  /// สแกนภาพเดี่ยวจาก Path (เช่น นำเข้าจาก ImagePicker)
  Future<ParsedSlip?> scanSingleImage(String filePath) async {
    if (!isSupported) return null;

    try {
      await SlipParserService.loadLearnedOwnData();
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

  /// ดึงที่อยู่ไฟล์รูปภาพสลิปจากระบบ Native (รองรับการค้นจาก path, assetId หรือ cleanId)
  Future<String?> getSlipImagePath({
    String? path,
    String? assetId,
    String? cleanId,
  }) async {
    if (!isSupported) return path;
    try {
      final res = await _channel.invokeMethod<String>('getSlipImage', {
        if (path != null) 'path': path,
        if (assetId != null) 'assetId': assetId,
        if (cleanId != null) 'cleanId': cleanId,
      });
      return res ?? path;
    } catch (e) {
      debugPrint('Error getting slip image from native: $e');
      return path;
    }
  }

  /// ตรวจสอบว่าสลิปนี้เคยถูกบันทึกเข้าระบบไปแล้วหรือไม่ (ตรวจสอบหลายชั้นเพื่อป้องกันสลิปซ้ำ 100%)
  bool _isSlipSaved(ParsedSlip slip, Set<String> savedKeys) {
    // 1. ตรวจจาก DeduplicationKey มาตรฐาน (Bank_RefNo หรือ Bank_Amount_Date)
    if (savedKeys.contains(slip.deduplicationKey)) return true;

    // 2. ตรวจจาก Asset ID หรือ File Path ของรูปภาพ
    if (savedKeys.contains(slip.id)) return true;
    if (slip.imagePath != null && savedKeys.contains(slip.imagePath)) return true;

    // 3. ตรวจจากเลขอ้างอิงสลิป (Reference Number) ไม่ว่าจะรูปแบบใด
    final ref = slip.referenceNo?.trim();
    if (ref != null && ref.isNotEmpty) {
      final cleanRef = ref.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
      if (cleanRef.isNotEmpty) {
        if (savedKeys.contains(cleanRef) ||
            savedKeys.contains('ref_$cleanRef') ||
            savedKeys.contains('${slip.bank.name}_$cleanRef')) {
          return true;
        }
      }
    }

    // 4. ตรวจจากยอดเงิน + วันที่ + เวลา (Fallback เมื่อไม่มี Ref No)
    final date = slip.date;
    final timeKey =
        '${slip.bank.name}_${slip.amount.toStringAsFixed(2)}_${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}_${date.hour}${date.minute}';
    if (savedKeys.contains(timeKey)) return true;

    return false;
  }

  /// บันทึกคีย์สลิปที่ยืนยันแล้วลง SharedPreferences เพื่อไม่ให้อ่านซ้ำอย่างเด็ดขาด
  Future<void> markSlipsAsSaved(List<ParsedSlip> slips) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedKeys = prefs.getStringList(_prefSavedSlipKeys)?.toSet() ?? <String>{};
      for (var s in slips) {
        savedKeys.add(s.deduplicationKey);
        savedKeys.add(s.id);
        if (s.imagePath != null) savedKeys.add(s.imagePath!);

        final ref = s.referenceNo?.trim();
        if (ref != null && ref.isNotEmpty) {
          final cleanRef = ref.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
          if (cleanRef.isNotEmpty) {
            savedKeys.add('${s.bank.name}_$cleanRef');
            savedKeys.add('ref_$cleanRef');
            savedKeys.add(cleanRef);
          }
        }

        final date = s.date;
        final timeKey =
            '${s.bank.name}_${s.amount.toStringAsFixed(2)}_${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}_${date.hour}${date.minute}';
        savedKeys.add(timeKey);
        final dayKey =
            '${s.bank.name}_${s.amount.toStringAsFixed(2)}_${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';
        savedKeys.add(dayKey);
      }
      await prefs.setStringList(_prefSavedSlipKeys, savedKeys.toList());
      // อัปเดต timestamp ล่าสุดหลังจากบันทึกแล้ว
      await prefs.setDouble(_prefLastScanTimestamp, DateTime.now().millisecondsSinceEpoch / 1000.0);
      await refreshUnscannedCount();
    } catch (e) {
      debugPrint('Error saving slip dedup keys: $e');
    }
  }

  /// ปลดล็อคคีย์สลิปเมื่อผู้ใช้ลบรายการธุรกรรมออก เพื่อให้สามารถสแกนสลิปรูปเดิมใหม่ได้
  Future<void> unmarkSlipSaved({
    String? referenceNo,
    String? assetId,
    String? imagePath,
    BankType? bank,
    double? amount,
    DateTime? date,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedKeys = prefs.getStringList(_prefSavedSlipKeys)?.toSet();
      if (savedKeys == null || savedKeys.isEmpty) return;

      if (assetId != null && assetId.isNotEmpty) {
        savedKeys.remove(assetId);
      }
      if (imagePath != null && imagePath.isNotEmpty) {
        savedKeys.remove(imagePath);
      }

      final ref = referenceNo?.trim();
      if (ref != null && ref.isNotEmpty) {
        final cleanRef = ref.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
        if (cleanRef.isNotEmpty) {
          savedKeys.remove(cleanRef);
          savedKeys.remove('ref_$cleanRef');
          if (bank != null) {
            savedKeys.remove('${bank.name}_$cleanRef');
          }
          savedKeys.removeWhere((k) => k.contains(cleanRef));
        }
      }

      if (bank != null && amount != null && date != null) {
        final timeKey =
            '${bank.name}_${amount.toStringAsFixed(2)}_${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}_${date.hour}${date.minute}';
        savedKeys.remove(timeKey);
        final dayKey =
            '${bank.name}_${amount.toStringAsFixed(2)}_${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';
        savedKeys.remove(dayKey);
      }

      await prefs.setStringList(_prefSavedSlipKeys, savedKeys.toList());
      await refreshUnscannedCount();
    } catch (e) {
      debugPrint('Error unmarking slip dedup keys: $e');
    }
  }

  /// ล้างแคชประวัติสลิปทั้งหมด เพื่อให้สามารถเริ่มสแกนใหม่อีกครั้งได้
  Future<void> clearAllSavedSlipKeys() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefSavedSlipKeys);
      await prefs.remove(_prefLastScanTimestamp);
      await refreshUnscannedCount();
    } catch (e) {
      debugPrint('Error clearing all saved slip keys: $e');
    }
  }

  /// ซิงก์ประวัติสลิปที่เคยบันทึกไว้จากเซิร์ฟเวอร์ (รองรับกรณีย้ายเครื่อง หรือลบแอพแล้วโหลดใหม่)
  Future<int> syncSavedSlipsFromServer({
    required String userId,
    required dynamic apiClient,
    bool overwrite = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final response = await apiClient.get(
        '/transactions?user_id=eq.$userId&select=id,note,amount,transaction_date,bank,reference_no,source',
      );
      if (response.statusCode != 200) return 0;
      final dynamic data = jsonDecode(response.body);
      if (data is! List) return 0;

      final savedKeys = overwrite
          ? <String>{}
          : (prefs.getStringList(_prefSavedSlipKeys)?.toSet() ?? <String>{});
      int restored = 0;

      for (var row in data) {
        if (row is! Map) continue;
        final note = row['note']?.toString() ?? '';
        final bankStr = row['bank']?.toString();
        final bank = (bankStr != null && bankStr.isNotEmpty)
            ? BankType.values.cast<BankType?>().firstWhere((b) => b?.name == bankStr, orElse: () => null)
            : BankType.detectFromText(note);

        // 1. ตรวจหา Ref number จากคอลัมน์ reference_no หรือจาก note
        String? refNo = row['reference_no']?.toString();
        if (refNo == null || refNo.isEmpty) {
          final refMatch = RegExp(r'\[Ref:([a-zA-Z0-9]+)\]').firstMatch(note);
          if (refMatch != null && refMatch.group(1) != null) {
            refNo = refMatch.group(1)!;
          }
        }
        if (refNo != null && refNo.isNotEmpty) {
          final cleanRef = refNo.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
          if (cleanRef.isNotEmpty) {
            if (bank != null && savedKeys.add('${bank.name}_$cleanRef')) restored++;
            savedKeys.add('ref_$cleanRef');
            savedKeys.add(cleanRef);
          }
        }

        // 2. ดึงจากยอดเงินและวันเวลา
        if (bank != null) {
          final amount =
              num.tryParse(row['amount']?.toString() ?? '')?.toDouble() ?? 0.0;
          final dateStr = row['transaction_date']?.toString();
          final date = dateStr != null ? DateTime.tryParse(dateStr)?.toLocal() : null;
          if (date != null) {
            final timeKey =
                '${bank.name}_${amount.toStringAsFixed(2)}_${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}_${date.hour}${date.minute}';
            if (savedKeys.add(timeKey)) restored++;
            final dayKey =
                '${bank.name}_${amount.toStringAsFixed(2)}_${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';
            savedKeys.add(dayKey);
          }
        }
      }

      if (overwrite || restored > 0) {
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

      final savedDaysBack = prefs.getInt('pref_slip_scan_selected_days_back') ?? 30;
      final effectiveDays = (savedDaysBack > 0) ? savedDaysBack.clamp(1, 365) : 30;
      final startDate = DateTime.now().subtract(Duration(days: effectiveDays));
      final startMs = startDate.millisecondsSinceEpoch.toDouble();
      final endMs = DateTime.now().millisecondsSinceEpoch.toDouble();

      final dynamic result = await _channel.invokeMethod('scanRecentSlips', {
        'daysBack': effectiveDays,
        'startTimestamp': startMs,
        'endTimestamp': endMs,
        'limit': effectiveDays >= 180 ? 1000 : 300,
        'lastScanTimestamp': 0.0,
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

        if (parsed != null && !_isSlipSaved(parsed, savedKeys)) {
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
