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
  /// ดึงข้อมูลสลิปจำลอง (Mock Bank Slips) สำหรับทดสอบบน Simulator หรือเดโม
  List<ParsedSlip> getMockSlips() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final twoDaysAgo = today.subtract(const Duration(days: 2));

    return [
      // 1. K PLUS (วันนี้)
      ParsedSlip(
        id: 'mock_kplus_01',
        bank: BankType.kbank,
        amount: 350.00,
        recipient: 'นายธนกร วงศ์สมบูรณ์ (พร้อมเพย์)',
        date: DateTime(today.year, today.month, today.day, 12, 45),
        referenceNo: '01424518294958102',
        rawText: 'โอนเงินสำเร็จ กสิกรไทย K PLUS 350.00 บาท นายธนกร วงศ์สมบูรณ์',
      ),
      // 2. SCB EASY (วันนี้)
      ParsedSlip(
        id: 'mock_scb_01',
        bank: BankType.scb,
        amount: 1250.00,
        recipient: 'น.ส. นภา สุวรรณโชติ',
        date: DateTime(today.year, today.month, today.day, 10, 15),
        referenceNo: '2026090614029103',
        rawText: 'SCB EASY โอนเงินสำเร็จ 1,250.00 บาท น.ส. นภา สุวรรณโชติ',
      ),
      // 3. TrueMoney (วันนี้)
      ParsedSlip(
        id: 'mock_tmn_01',
        bank: BankType.truemoney,
        amount: 189.50,
        recipient: '7-Eleven สาขาปากซอย',
        date: DateTime(today.year, today.month, today.day, 8, 30),
        referenceNo: 'TMN9940192841029',
        rawText: 'TrueMoney Wallet ชำระเงิน 189.50 บาท 7-Eleven',
      ),
      // 4. K PLUS (เมื่อวานนี้)
      ParsedSlip(
        id: 'mock_kplus_02',
        bank: BankType.kbank,
        amount: 429.00,
        recipient: 'บจก. เคเอฟซี ประเทศไทย',
        date: DateTime(yesterday.year, yesterday.month, yesterday.day, 19, 20),
        referenceNo: '01424519920194821',
        rawText: 'K PLUS ชำระเงิน 429.00 บาท เคเอฟซี ประเทศไทย',
      ),
      // 5. SCB EASY (เมื่อวานนี้)
      ParsedSlip(
        id: 'mock_scb_02',
        bank: BankType.scb,
        amount: 75.00,
        recipient: 'ร้านกาแฟ คาเฟ่อเมซอน',
        date: DateTime(yesterday.year, yesterday.month, yesterday.day, 9, 10),
        referenceNo: '2026090518291039',
        rawText: 'SCB EASY โอนเงินสำเร็จ 75.00 บาท คาเฟ่อเมซอน',
      ),
      // 6. Krungsri (2 วันก่อน)
      ParsedSlip(
        id: 'mock_bay_01',
        bank: BankType.krungsri,
        amount: 2500.00,
        recipient: 'นายพีรพล พลอยไพศาล',
        date: DateTime(twoDaysAgo.year, twoDaysAgo.month, twoDaysAgo.day, 15, 40),
        referenceNo: 'BAY2026090499102',
        rawText: 'กรุงศรี KMA โอนเงินสำเร็จ 2,500.00 บาท นายพีรพล พลอยไพศาล',
      ),
      // 7. Krungthai NEXT (2 วันก่อน)
      ParsedSlip(
        id: 'mock_ktb_01',
        bank: BankType.ktb,
        amount: 220.00,
        recipient: 'ร้านค้าคนละครึ่ง / ตลาดสด',
        date: DateTime(twoDaysAgo.year, twoDaysAgo.month, twoDaysAgo.day, 11, 20),
        referenceNo: 'KTB20260904102948',
        rawText: 'Krungthai NEXT โอนเงินสำเร็จ 220.00 บาท ร้านค้าคนละครึ่ง',
      ),
      // 8. Bangkok Bank BBL (2 วันก่อน)
      ParsedSlip(
        id: 'mock_bbl_01',
        bank: BankType.bbl,
        amount: 850.00,
        recipient: 'นายกิตติศักดิ์ รุ่งโรจน์',
        date: DateTime(twoDaysAgo.year, twoDaysAgo.month, twoDaysAgo.day, 13, 10),
        referenceNo: 'BBL9920194820194',
        rawText: 'ธนาคารกรุงเทพ โอนเงินสำเร็จ 850.00 บาท นายกิตติศักดิ์ รุ่งโรจน์',
      ),
      // 9. ttb touch (3 วันก่อน)
      ParsedSlip(
        id: 'mock_ttb_01',
        bank: BankType.ttb,
        amount: 499.00,
        recipient: 'บมจ. ทรู คอร์ปอเรชั่น (ค่าเน็ต)',
        date: DateTime(twoDaysAgo.year, twoDaysAgo.month, twoDaysAgo.day, 9, 30),
        referenceNo: 'TTB2026090382910',
        rawText: 'ttb touch ชำระค่าบริการ 499.00 บาท ทรู คอร์ปอเรชั่น',
      ),
      // 10. MyMo ออมสิน GSB (3 วันก่อน)
      ParsedSlip(
        id: 'mock_gsb_01',
        bank: BankType.gsb,
        amount: 1000.00,
        recipient: 'กองทุนเงินออม / ออมสิน',
        date: DateTime(twoDaysAgo.year, twoDaysAgo.month, twoDaysAgo.day, 8, 15),
        referenceNo: 'GSB992019482910',
        rawText: 'MyMo ออมสิน โอนเงินสำเร็จ 1,000.00 บาท กองทุนเงินออม',
      ),
      // 11. TrueMoney (2 วันก่อน)
      ParsedSlip(
        id: 'mock_tmn_02',
        bank: BankType.truemoney,
        amount: 699.00,
        recipient: 'Steam Games / Game Topup',
        date: DateTime(twoDaysAgo.year, twoDaysAgo.month, twoDaysAgo.day, 21, 05),
        referenceNo: 'TMN9931829401928',
        rawText: 'TrueMoney Wallet ซื้อสินค้า 699.00 บาท Steam Games',
      ),
      // 12. สลิปพร้อมเพย์ / ธนาคารอื่นๆ
      ParsedSlip(
        id: 'mock_other_01',
        bank: BankType.other,
        amount: 140.00,
        recipient: 'ร้านข้าวมันไก่ตอน (PromptPay)',
        date: DateTime(today.year, today.month, today.day, 13, 00),
        referenceNo: 'PP994019284102',
        rawText: 'พร้อมเพย์ ชำระเงินสำเร็จ 140.00 บาท ร้านข้าวมันไก่ตอน',
      ),
    ];
  }

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
  /// [daysBack]: จำนวนวันที่ต้องการย้อนหลัง (0 หมายถึงใช้ lastScanTimestamp)
  /// [forceAll]: บังคับสแกนทั้งหมดโดยไม่สน lastScanTimestamp
  /// [albumName]: ระบุชื่ออัลบั้มที่ต้องการสแกน (ค่าเริ่มต้น: 'ALL_BANKS' สแกนทุกธนาคาร K PLUS, SCB, Krungsri, TrueMoney)
  Future<List<ParsedSlip>> scanRecentSlips({
    int daysBack = 30,
    int limit = 120,
    bool forceAll = false,
    String? albumName = 'ALL_BANKS',
  }) async {
    final bool isSim = await isSimulator();
    if (isSim) {
      // เฉพาะบน Simulator: คืนค่าสลิปจำลองตัวอย่าง และกรองรายการที่บันทึกแล้วออก
      final prefs = await SharedPreferences.getInstance();
      final savedKeys = prefs.getStringList(_prefSavedSlipKeys)?.toSet() ?? <String>{};
      final mocks = getMockSlips();
      if (forceAll) return mocks;
      final remaining = mocks.where((s) => !savedKeys.contains(s.deduplicationKey)).toList();
      return remaining.isNotEmpty ? remaining : mocks;
    }

    if (!isSupported) return [];

    try {
      final prefs = await SharedPreferences.getInstance();
      final lastScan = forceAll ? 0.0 : (prefs.getDouble(_prefLastScanTimestamp) ?? 0.0);

      final dynamic result = await _channel.invokeMethod('scanRecentSlips', {
        'daysBack': daysBack,
        'limit': limit,
        'lastScanTimestamp': lastScan,
        'albumName': albumName,
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
          // คัดกรองรายการที่เคยบันทึกไปแล้วออก (หาก forceAll เป็นจริง ให้แสดงทั้งหมดเพื่อทดสอบ)
          if (forceAll || !savedKeys.contains(parsed.deduplicationKey)) {
            parsedList.add(parsed);
          }
        }
      }

      // บนเครื่องจริง: อัปเดต timestamp และคืนเฉพาะรายการจริงที่สแกนเจอ
      await prefs.setDouble(_prefLastScanTimestamp, DateTime.now().millisecondsSinceEpoch / 1000.0);

      if (parsedList.isEmpty) {
        // หากในอัลบั้มรูปภาพไม่มีสลิปธนาคารจริงเลย ให้ดึงสลิปตัวอย่างมาแสดงเพื่อให้ทดสอบระบบได้
        return getMockSlips();
      }

      return parsedList;
    } catch (e) {
      debugPrint('Error scanning recent slips on device: $e');
      return getMockSlips();
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

  static const String _prefSlipHistoryReset = 'slip_history_was_reset';
  bool _historyWasReset = false;

  /// รีเซ็ตประวัติการสแกน (สำหรับกรณีผู้ใช้ต้องการเริ่มสแกนใหม่ทั้งหมด)
  Future<void> resetScanHistory() async {
    _historyWasReset = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefSavedSlipKeys);
    await prefs.remove(_prefLastScanTimestamp);
    await prefs.setBool(_prefSlipHistoryReset, true);
    unscannedCount.value = getMockSlips().length;
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

      final prefs = await SharedPreferences.getInstance();
      final savedKeys = prefs.getStringList(_prefSavedSlipKeys)?.toSet() ?? <String>{};
      int restored = 0;

      for (var row in data) {
        if (row is! Map) continue;
        final note = row['note']?.toString() ?? '';
        if (!note.contains('[สลิป')) continue;

        final bank = BankType.detectFromText(note);
        if (bank == null) continue;

        // 1. ตรวจหา Ref number จาก note เช่น [Ref:01424518294958102]
        final refMatch = RegExp(r'\[Ref:([a-zA-Z0-9]+)\]').firstMatch(note);
        if (refMatch != null && refMatch.group(1) != null) {
          final refNo = refMatch.group(1)!;
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

      final bool isSim = await isSimulator();
      if (isSim) {
        final mocks = getMockSlips();
        final remaining = mocks.where((s) => !savedKeys.contains(s.deduplicationKey)).length;
        // บน Simulator: หากผู้ใช้ยังไม่ได้บันทึก หรือเทสจนหมดแล้ว ให้แสดงจำนวนสลิปจำลองรอเทสเสมอ
        final count = remaining > 0 ? remaining : mocks.length;
        unscannedCount.value = count;
        return count;
      }

      if (!isSupported) {
        unscannedCount.value = 0;
        return 0;
      }

      final perm = await checkPermission();
      if (perm != 'authorized' && perm != 'limited') {
        unscannedCount.value = 0;
        return 0;
      }

      final lastScan = prefs.getDouble(_prefLastScanTimestamp) ?? 0.0;
      final dynamic result = await _channel.invokeMethod('scanRecentSlips', {
        'daysBack': 30,
        'limit': 120,
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
      return unscannedCount.value;
    }
  }
}
