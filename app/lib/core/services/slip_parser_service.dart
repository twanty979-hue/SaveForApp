import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/auth/domain/auth_session.dart';

enum BankType {
  kbank,
  scb,
  krungsri,
  ktb,
  bbl,
  ttb,
  gsb,
  truemoney,
  other;

  String get displayName {
    switch (this) {
      case BankType.kbank:
        return 'กสิกรไทย (KBank)';
      case BankType.scb:
        return 'ไทยพาณิชย์ (SCB)';
      case BankType.krungsri:
        return 'กรุงศรี (BAY)';
      case BankType.ktb:
        return 'กรุงไทย (KTB)';
      case BankType.bbl:
        return 'กรุงเทพ (BBL)';
      case BankType.ttb:
        return 'ทีทีบี (TTB)';
      case BankType.gsb:
        return 'ออมสิน (GSB)';
      case BankType.truemoney:
        return 'ทรูมันนี่ (TrueMoney)';
      case BankType.other:
        return 'สลิปธนาคาร';
    }
  }

  int get brandColorValue {
    switch (this) {
      case BankType.kbank:
        return 0xFF00A950;
      case BankType.scb:
        return 0xFF4E2A84;
      case BankType.krungsri:
        return 0xFF7A6400;
      case BankType.ktb:
        return 0xFF00AEEF;
      case BankType.bbl:
        return 0xFF1E3A8A;
      case BankType.ttb:
        return 0xFF002D62;
      case BankType.gsb:
        return 0xFFEB1985;
      case BankType.truemoney:
        return 0xFFFF6600;
      case BankType.other:
        return 0xFF00A88F;
    }
  }

  static BankType? detectFromText(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('กสิกร') || lower.contains('kbank') || lower.contains('k plus') || lower.contains('k+') || lower.contains('kbiz')) {
      return BankType.kbank;
    }
    if (lower.contains('ไทยพาณิชย์') || lower.contains('scb') || lower.contains('แม่มณี') || lower.contains('easy')) {
      return BankType.scb;
    }
    if (lower.contains('กรุงศรี') || lower.contains('krungsri') || lower.contains('bay') || lower.contains('kma')) {
      return BankType.krungsri;
    }
    if (lower.contains('กรุงไทย') || lower.contains('krungthai') || lower.contains('ktb') || lower.contains('เป๋าตัง') || lower.contains('next')) {
      return BankType.ktb;
    }
    if (lower.contains('กรุงเทพ') || lower.contains('bangkok bank') || lower.contains('bualuang') || lower.contains('bbl')) {
      return BankType.bbl;
    }
    if (lower.contains('ทหารไทย') || lower.contains('ttb') || lower.contains('tmb') || lower.contains('ธนชาต')) {
      return BankType.ttb;
    }
    if (lower.contains('ออมสิน') || lower.contains('gsb') || lower.contains('mymo')) {
      return BankType.gsb;
    }
    if (lower.contains('truemoney') || lower.contains('ทรูมันนี่') || lower.contains('true money') || lower.contains('tmn')) {
      return BankType.truemoney;
    }
    if (lower.contains('สลิป') || lower.contains('slip') || lower.contains('พร้อมเพย์') || lower.contains('promptpay') || lower.contains('prompt')) {
      return BankType.other;
    }
    return null;
  }
}

class ParsedSlip {
  final String id;
  final BankType bank;
  final double amount;
  final String recipient;
  final String? recipientAccount;
  final String? sender;
  final String? senderAccount;
  final DateTime date;
  final String? referenceNo;
  final String rawText;
  final String? imagePath;
  final String? albumName;
  bool isSelected;
  String? customNote;
  bool includeRecipientInNote;
  BankType? destinationBank;
  bool isTransfer;

  ParsedSlip({
    required this.id,
    required this.bank,
    required this.amount,
    required this.recipient,
    this.recipientAccount,
    this.sender,
    this.senderAccount,
    required this.date,
    this.referenceNo,
    required this.rawText,
    this.imagePath,
    this.albumName,
    this.isSelected = true,
    this.customNote,
    this.includeRecipientInNote = true,
    this.destinationBank,
    this.isTransfer = false,
  });

  /// ชื่อที่จะนำไปแสดงผลบนหน้าจอ
  String get displayTitle {
    if (customNote != null && customNote!.trim().isNotEmpty) {
      return customNote!.trim();
    }
    if (isTransfer) {
      return 'ย้ายเงิน';
    }
    return recipient;
  }

  /// ข้อความชื่อรายการสำหรับบันทึกลงฐานข้อมูล
  String get finalFormattedNoteTitle {
    final custom = customNote?.trim();
    if (custom != null && custom.isNotEmpty) {
      return custom;
    }
    if (isTransfer) {
      return 'ย้ายเงิน';
    }
    return recipient.trim();
  }

  /// สร้าง unique key สำหรับตรวจสอบการบันทึกซ้ำ
  String get deduplicationKey {
    if (referenceNo != null && referenceNo!.trim().isNotEmpty) {
      return '${bank.name}_${referenceNo!.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '')}';
    }
    // Fallback: รวมยอดเงินและเวลา (ถึงระดับชั่วโมงและนาที)
    return '${bank.name}_${amount.toStringAsFixed(2)}_${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}_${date.hour}${date.minute}';
  }
}

class SlipParserService {
  SlipParserService._();
  static final SlipParserService instance = SlipParserService._();

  /// รายชื่อและเลขบัญชีของเจ้าของเครื่องที่ระบบเรียนรู้ไว้จากการย้ายเงิน
  static final Set<String> learnedOwnNames = {};
  static final Set<String> learnedOwnAccounts = {};

  /// โหลดข้อมูลบัญชีตนเองที่เคยเรียนรู้ไว้จากหน่วยความจำเครื่อง แยกตาม User ID (SaaS Multi-tenant)
  static Future<void> loadLearnedOwnData([String? userId]) async {
    try {
      final activeUid = userId ?? AuthSession.userId ?? 'default';
      final prefs = await SharedPreferences.getInstance();
      final namesKey = 'learned_own_account_names_$activeUid';
      final accountsKey = 'learned_own_account_numbers_$activeUid';

      final names = prefs.getStringList(namesKey) ?? [];
      final accounts = prefs.getStringList(accountsKey) ?? [];

      learnedOwnNames.clear();
      learnedOwnAccounts.clear();

      learnedOwnNames.addAll(names);
      learnedOwnAccounts.addAll(accounts);

      // ดึงชื่อโปรไฟล์ของ User ในระบบ SaaS เข้าไปใน learnedOwnNames โดยอัตโนมัติ
      final profileName = AuthSession.displayName;
      if (profileName != null && profileName.trim().isNotEmpty) {
        learnedOwnNames.add(profileName.trim());
      }
    } catch (_) {}
  }

  /// ล้างข้อมูลบัญชีที่จำไว้ใน RAM (ใช้ตอนสลับบัญชีผู้ใช้หรือ Logout)
  static void clearLearnedData() {
    learnedOwnNames.clear();
    learnedOwnAccounts.clear();
  }

  /// บันทึกจดจำชื่อหรือเลขบัญชี/พร้อมเพย์ของตนเองลงในระบบอัตโนมัติ แยกตาม User ID (SaaS Multi-tenant)
  static Future<void> learnOwnAccount({
    String? name,
    String? accountNumber,
    String? userId,
  }) async {
    final activeUid = userId ?? AuthSession.userId ?? 'default';
    bool changed = false;
    if (name != null && name.trim().isNotEmpty) {
      final clean = name.trim();
      final lower = clean.toLowerCase();
      // ป้องกันไม่ให้จดจำคำทั่วไป เช่น "ย้ายเงิน", "โอนเงิน", "พร้อมเพย์" หรือชื่อธนาคารเป็นชื่อบุคคล
      if (clean.length >= 3 &&
          !lower.contains('ย้ายเงิน') &&
          !lower.contains('โอนเงิน') &&
          !lower.contains('สลิป') &&
          !lower.contains('prompt') &&
          !lower.contains('พร้อมเพย์') &&
          BankType.detectFromText(clean) == null &&
          learnedOwnNames.add(clean)) {
        changed = true;
      }
    }
    if (accountNumber != null && accountNumber.trim().isNotEmpty) {
      final clean = accountNumber.replaceAll(RegExp(r'[^0-9]'), '');
      if (clean.length >= 4 && learnedOwnAccounts.add(clean)) {
        changed = true;
      }
    }
    if (changed) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList('learned_own_account_names_$activeUid', learnedOwnNames.toList());
        await prefs.setStringList('learned_own_account_numbers_$activeUid', learnedOwnAccounts.toList());
      } catch (_) {}
    }
  }

  /// ลบหรือยกเลิกการจดจำชื่อหรือเลขบัญชี แยกตาม User ID (SaaS Multi-tenant Self-healing)
  static Future<void> forgetOwnAccount({
    String? name,
    String? accountNumber,
    String? userId,
  }) async {
    final activeUid = userId ?? AuthSession.userId ?? 'default';
    bool changed = false;
    if (name != null && name.trim().isNotEmpty) {
      final cleanName = name.trim().toLowerCase();
      final toRemove = learnedOwnNames.where((n) {
        final l = n.trim().toLowerCase();
        return l == cleanName || isSamePersonName(n, name);
      }).toList();
      for (final r in toRemove) {
        if (learnedOwnNames.remove(r)) {
          changed = true;
        }
      }
    }
    if (accountNumber != null && accountNumber.trim().isNotEmpty) {
      final clean = accountNumber.replaceAll(RegExp(r'[^0-9]'), '');
      if (clean.length >= 4 && learnedOwnAccounts.remove(clean)) {
        changed = true;
      }
    }
    if (changed) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList('learned_own_account_names_$activeUid', learnedOwnNames.toList());
        await prefs.setStringList('learned_own_account_numbers_$activeUid', learnedOwnAccounts.toList());
      } catch (_) {}
    }
  }

  /// ตรวจสอบและสกัดข้อมูลสลิปจากข้อความ OCR
  ParsedSlip? parse({
    required String id,
    required List<String> lines,
    required String fullText,
    DateTime? fallbackDate,
    String? imagePath,
    String? albumName,
    String? knownOwnerName,
  }) {
    if (lines.isEmpty && fullText.trim().isEmpty) return null;

    final lower = fullText.toLowerCase();

    // 1. ระบุธนาคาร (ลำดับความสำคัญ: อัลบั้ม -> ส่วนหัวสลิปก่อน "ไปยัง" -> ทั้งข้อความ)
    final bank = _detectBank(lines, lower, albumName: albumName);

    // 2. ดึงยอดเงิน (Amount)
    final amount = _extractAmount(lines, fullText);
    debugPrint('[SlipParser] Parsing id: $id, lines: ${lines.length}, detected bank: ${bank.name}, amount: $amount');

    if (amount == null || amount <= 0) {
      debugPrint('[SlipParser] Discarded slip: amount could not be extracted or <= 0');
      return null;
    }

    // 3. ดึงชื่อผู้รับโอน (Recipient)
    final recipient = _extractRecipient(lines, fullText, bank);

    // ดึงชื่อผู้โอน (Sender)
    final sender = _extractSender(lines, fullText);

    // 4. ดึงวันที่ทำรายการ
    final date = _extractDate(lines, fullText) ?? fallbackDate ?? DateTime.now();

    // 5. ดึงรหัสอ้างอิง
    final ref = _extractReferenceNo(lines, fullText);

    // 6. ดึงธนาคารปลายทาง (ถ้ามี)
    final destinationBank = _extractDestinationBank(lines, fullText, bank);

    // ดึงเลขบัญชีหรือหมายเลขพร้อมเพย์ของผู้รับ (ถ้ามี)
    final recipientAccount = _extractRecipientAccount(lines, recipient, fullText);

    // ดึงเลขบัญชีของผู้โอน (ถ้ามี)
    final senderAccount = _extractSenderAccount(lines, sender, fullText);

    // 7. ตรวจสอบว่าเป็นการย้ายเงินระหว่างบัญชีตนเองหรือไม่ (Internal Transfer)
    final isTransfer = _detectIsTransfer(
      lines,
      fullText,
      recipient,
      destinationBank,
      knownOwnerName: knownOwnerName ?? AuthSession.displayName,
      recipientAccount: recipientAccount,
      senderName: sender,
    );

    // หากเป็นการย้ายเงินระหว่างบัญชีตนเอง แต่ยังไม่ระบุธนาคารปลายทาง ให้ตรวจหาจากคำในสลิป
    var finalDestBank = destinationBank;
    if (isTransfer && finalDestBank == null) {
      if (lower.contains('scb') || lower.contains('ไทยพาณิชย์')) {
        finalDestBank = BankType.scb;
      } else if (lower.contains('kbank') || lower.contains('กสิกร')) {
        finalDestBank = BankType.kbank;
      } else if (lower.contains('krungthai') || lower.contains('กรุงไทย') || lower.contains('ktb')) {
        finalDestBank = BankType.ktb;
      } else if (lower.contains('ttb') || lower.contains('ทหารไทย')) {
        finalDestBank = BankType.ttb;
      } else if (lower.contains('bay') || lower.contains('กรุงศรี')) {
        finalDestBank = BankType.krungsri;
      } else if (lower.contains('bbl') || lower.contains('กรุงเทพ')) {
        finalDestBank = BankType.bbl;
      } else if (lower.contains('gsb') || lower.contains('ออมสิน')) {
        finalDestBank = BankType.gsb;
      } else if (lower.contains('truemoney') || lower.contains('ทรูมันนี่')) {
        finalDestBank = BankType.truemoney;
      } else {
        finalDestBank = bank == BankType.kbank ? BankType.scb : BankType.kbank;
      }
    }

    return ParsedSlip(
      id: id,
      bank: bank,
      amount: amount,
      recipient: recipient.isNotEmpty ? recipient : (isTransfer ? 'ย้ายเงิน' : 'โอนเงิน (${bank.displayName})'),
      recipientAccount: recipientAccount,
      sender: sender.isNotEmpty ? sender : null,
      senderAccount: senderAccount,
      date: date,
      referenceNo: ref,
      rawText: fullText,
      imagePath: imagePath,
      albumName: albumName,
      destinationBank: finalDestBank,
      isTransfer: isTransfer,
    );
  }

  String? _extractSenderAccount(List<String> lines, String sender, String fullText) {
    if (sender.isNotEmpty) {
      int idx = -1;
      for (int i = 0; i < lines.length; i++) {
        if (lines[i].contains(sender)) {
          idx = i;
          break;
        }
      }
      if (idx != -1) {
        for (int i = idx + 1; i < lines.length && i <= idx + 4; i++) {
          final line = lines[i].trim();
          if (_isAccountLine(line)) {
            return line;
          }
        }
      }
    }
    return null;
  }

  String? _extractRecipientAccount(List<String> lines, String recipient, String fullText) {
    if (recipient.isNotEmpty) {
      int idx = -1;
      for (int i = 0; i < lines.length; i++) {
        if (lines[i].contains(recipient)) {
          idx = i;
          break;
        }
      }
      if (idx != -1) {
        for (int i = idx + 1; i < lines.length && i <= idx + 4; i++) {
          final line = lines[i].trim();
          if (_isAccountLine(line)) {
            return line;
          }
        }
      }
    }
    final match = RegExp(r'\b(?:[0-9xX]{3,}-[0-9xX\-]+|[0-9]{10,13})\b').firstMatch(fullText);
    return match?.group(0);
  }

  BankType _detectBank(List<String> lines, String lower, {String? albumName}) {
    if (albumName != null && albumName.isNotEmpty) {
      final detectedFromAlbum = BankType.detectFromText(albumName);
      if (detectedFromAlbum != null && detectedFromAlbum != BankType.other) {
        return detectedFromAlbum;
      }
    }

    // 1. ตรวจสอบธนาคารต้นทางจากส่วนหัวสลิป (ก่อนบรรทัด "ไปยัง")
    int toIndex = -1;
    for (int i = 0; i < lines.length; i++) {
      final l = lines[i].trim().toLowerCase();
      if (l.startsWith('ไปยัง') ||
          l.startsWith('โอนไปยัง') ||
          l.startsWith('ส่งไปยัง') ||
          l.startsWith('to:') ||
          l == 'to') {
        toIndex = i;
        break;
      }
    }

    final headerLines = toIndex > 0 ? lines.sublist(0, toIndex) : lines.take(6);
    for (final line in headerLines) {
      final detected = BankType.detectFromText(line);
      if (detected != null && detected != BankType.other) {
        return detected;
      }
    }

    // 2. Fallback ตรวจสอบจากทั้งข้อความ
    if (lower.contains('กสิกร') || lower.contains('kbank') || lower.contains('k plus') || lower.contains('k+') || lower.contains('kbiz') || lower.contains('kasikorn')) {
      return BankType.kbank;
    }
    if (lower.contains('ไทยพาณิชย์') || lower.contains('scb') || lower.contains('แม่มณี') || lower.contains('easy')) {
      return BankType.scb;
    }
    if (lower.contains('กรุงศรี') || lower.contains('krungsri') || lower.contains('kma') || lower.contains('bay')) {
      return BankType.krungsri;
    }
    if (lower.contains('กรุงไทย') || lower.contains('krungthai') || lower.contains('ktb') || lower.contains('next') || lower.contains('เป๋าตัง')) {
      return BankType.ktb;
    }
    if (lower.contains('กรุงเทพ') || lower.contains('bangkok bank') || lower.contains('bualuang') || lower.contains('bbl')) {
      return BankType.bbl;
    }
    if (lower.contains('ทหารไทย') || lower.contains('ttb') || lower.contains('tmb') || lower.contains('ธนชาต')) {
      return BankType.ttb;
    }
    if (lower.contains('ออมสิน') || lower.contains('gsb') || lower.contains('mymo')) {
      return BankType.gsb;
    }
    if (lower.contains('truemoney') || lower.contains('ทรูมันนี่') || lower.contains('true money') || lower.contains('tmn')) {
      return BankType.truemoney;
    }
    if (lower.contains('พร้อมเพย์') || lower.contains('promptpay')) {
      return BankType.other;
    }
    return BankType.other;
  }

  bool _isFeeLine(String line) {
    final lower = line.toLowerCase();
    return lower.contains('ค่าธรรมเนียม') || lower.contains('fee');
  }

  double? _extractAmount(List<String> lines, String fullText) {
    // 1. ระดับความมั่นใจสูงสุด (High Priority): มองหาข้อความระบุยอดเงินชัดเจน พร้อมทศนิยม 2 ตำแหน่ง
    // เช่น "ยอดชำระทั้งหมด ฿ 82.00", "จำนวนเงิน 1,500.00 บาท", "ยอดเงิน: 250.00"
    // สำคัญ: ห้ามรวมคำว่า "ชำระเงิน" เดี่ยวๆ เพราะเป็นชื่อฟิลด์ผู้รับ เช่น "ชำระเงิน 7-Eleven"
    final highConfidenceDecimalRegex = RegExp(
      r'(?:ยอดชำระทั้งหมด|ยอดชำระสุทธิ|ยอดเงินที่ชำระ|จำนวนเงินที่โอน|จำนวนเงินโอน|จำนวนเงิน|จํานวนเงิน|ยอดเงิน|ยอดโอน|ยอดชำระ|ยอดรวมสุทธิ|ยอดรวม|total\s*amount|amount)\s*[:]?\s*(?:THB|฿|บาท)?\s*([0-9]{1,3}(?:,[0-9]{3})*\.[0-9]{2}|[0-9]+\.[0-9]{2})\b(?!\s*[-/a-zA-Z])',
      caseSensitive: false,
    );

    final highMatch = highConfidenceDecimalRegex.firstMatch(fullText);
    if (highMatch != null) {
      final clean = highMatch.group(1)?.replaceAll(',', '');
      if (clean != null) {
        final val = double.tryParse(clean);
        if (val != null && val > 0 && val < 50000000) return val;
      }
    }

    // 2. ป้ายกำกับยอดเงินอยู่คนละบรรทัดกับตัวเลขทศนิยม (เช่น K PLUS / SCB บรรทัดถัดไป)
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim().toLowerCase();
      if (_isFeeLine(line)) continue;

      final isAmountLabel = line == 'จำนวนเงิน' ||
          line == 'จํานวนเงิน' ||
          line.startsWith('จำนวนเงิน') ||
          line.startsWith('จํานวนเงิน') ||
          line.startsWith('ยอดเงิน') ||
          line.startsWith('ยอดโอน') ||
          line.startsWith('ยอดชำระทั้งหมด') ||
          line.startsWith('ยอดชำระสุทธิ') ||
          line.startsWith('ยอดชำระ') ||
          line == 'amount' ||
          line.startsWith('amount') ||
          line.startsWith('total amount');

      if (isAmountLabel) {
        for (int j = i + 1; j < lines.length && j <= i + 3; j++) {
          final nextLine = lines[j].trim();
          if (_isFeeLine(nextLine)) continue;
          final lowerNext = nextLine.toLowerCase();
          if (lowerNext == '(บาท)' || lowerNext == 'บาท' || lowerNext == 'baht' || lowerNext == 'thb' || lowerNext == ':') {
            continue;
          }
          final amountMatch = RegExp(r'^([0-9]{1,3}(?:,[0-9]{3})*\.[0-9]{2}|[0-9]+\.[0-9]{2})$').firstMatch(nextLine) ??
              RegExp(r'([0-9]{1,3}(?:,[0-9]{3})*\.[0-9]{2}|[0-9]+\.[0-9]{2})\b(?!\s*[-/a-zA-Z])').firstMatch(nextLine);
          if (amountMatch != null) {
            final clean = amountMatch.group(1)?.replaceAll(',', '');
            if (clean != null) {
              final val = double.tryParse(clean);
              if (val != null && val > 0 && val < 50000000) return val;
            }
          }
        }
      }
    }

    // 3. สแกนหาตัวเลขทศนิยม 2 ตำแหน่งที่มีสัญลักษณ์สกุลเงิน (฿, THB, บาท) อยู่ติดกัน
    // เช่น "฿ 82.00" ใน TrueMoney หรือ "1,500.00 บาท"
    final regexCurrencyDecimal = RegExp(
      r'(?:(?:฿|thb)\s*([0-9]{1,3}(?:,[0-9]{3})*\.[0-9]{2}|[0-9]+\.[0-9]{2})\b(?!\s*[-/a-zA-Z])|([0-9]{1,3}(?:,[0-9]{3})*\.[0-9]{2}|[0-9]+\.[0-9]{2})\s*(?:บาท|baht|thb)\b)',
      caseSensitive: false,
    );

    for (final line in lines) {
      if (_isFeeLine(line)) continue;
      final currencyMatch = regexCurrencyDecimal.firstMatch(line);
      if (currencyMatch != null) {
        final rawNum = currencyMatch.group(1) ?? currencyMatch.group(2);
        final clean = rawNum?.replaceAll(',', '');
        if (clean != null) {
          final val = double.tryParse(clean);
          if (val != null && val > 0 && val < 50000000) return val;
        }
      }
    }

    // 4. ตัวเลขทศนิยม 2 ตำแหน่งโดดๆ ในบรรทัด (พบบ่อยใน K PLUS สลิปแบบกราฟิกธีม)
    for (final line in lines) {
      if (_isFeeLine(line)) continue;
      final trimmed = line.trim();
      final standaloneMatch = RegExp(r'^([0-9]{1,3}(?:,[0-9]{3})*\.[0-9]{2})$').firstMatch(trimmed);
      if (standaloneMatch != null) {
        final clean = standaloneMatch.group(1)?.replaceAll(',', '');
        if (clean != null) {
          final val = double.tryParse(clean);
          if (val != null && val > 0 && val < 50000000) return val;
        }
      }
    }

    // 5. สแกนหาตัวเลขทศนิยม 2 ตำแหน่งในบรรทัดทั่วไป (ข้ามบรรทัดค่าธรรมเนียมและเลขอ้างอิง)
    final anyDecimalRegex = RegExp(r'\b([0-9]{1,3}(?:,[0-9]{3})*|[0-9]+)\s*[\.]\s*([0-9]{2})\b(?!\s*[-/a-zA-Z])');
    for (final line in lines) {
      if (_isFeeLine(line)) continue;
      if (line.contains('เลขที่') || line.contains('รหัส') || line.contains('ref') || line.contains('order')) continue;
      final match = anyDecimalRegex.firstMatch(line);
      if (match != null) {
        final whole = match.group(1)?.replaceAll(',', '').trim() ?? '';
        final dec = match.group(2)?.trim() ?? '';
        final val = double.tryParse('$whole.$dec');
        if (val != null && val > 0 && val < 50000000) {
          return val;
        }
      }
    }

    // 6. ระดับตัวเลขจำนวนเต็ม (Integer) - เมื่อสลิปไม่มีทศนิยม เช่น ธีม K PLUS "864" หรือ "จำนวนเงิน 500 บาท"
    final integerKeywordRegex = RegExp(
      r'(?:ยอดชำระทั้งหมด|ยอดชำระสุทธิ|ยอดเงินที่ชำระ|จำนวนเงินที่โอน|จำนวนเงินโอน|จำนวนเงิน|จํานวนเงิน|ยอดเงิน|ยอดโอน|ยอดชำระ|ยอดรวมสุทธิ|ยอดรวม|total\s*amount|amount)\s*[:]?\s*(?:THB|฿|บาท)?\s*([0-9]{1,3}(?:,[0-9]{3})*|[1-9][0-9]*)\b(?!\s*[-/a-zA-Z])',
      caseSensitive: false,
    );
    for (final line in lines) {
      if (_isFeeLine(line)) continue;
      final intMatch = integerKeywordRegex.firstMatch(line);
      if (intMatch != null) {
        final clean = intMatch.group(1)?.replaceAll(',', '').trim();
        if (clean != null) {
          final val = double.tryParse(clean);
          if (val != null && val > 0 && val < 50000000) {
            final intVal = val.toInt();
            if (!(intVal >= 2020 && intVal <= 2030) && !(intVal >= 2560 && intVal <= 2575)) {
              return val;
            }
          }
        }
      }
    }

    // 7. ตัวเลขจำนวนเต็มที่มีสัญลักษณ์สกุลเงิน เช่น "100 บาท", "฿ 500"
    final integerCurrencyRegex = RegExp(
      r'(?:(?:฿|thb)\s*([0-9]{1,3}(?:,[0-9]{3})*|[1-9][0-9]*)\b(?!\s*[-/a-zA-Z])|([0-9]{1,3}(?:,[0-9]{3})*|[1-9][0-9]*)\s*(?:บาท|baht|thb)\b)',
      caseSensitive: false,
    );
    for (final line in lines) {
      if (_isFeeLine(line)) continue;
      final intMatch = integerCurrencyRegex.firstMatch(line);
      if (intMatch != null) {
        final rawNum = intMatch.group(1) ?? intMatch.group(2);
        final clean = rawNum?.replaceAll(',', '').trim();
        if (clean != null) {
          final val = double.tryParse(clean);
          if (val != null && val > 0 && val < 50000000) {
            final intVal = val.toInt();
            if (!(intVal >= 2020 && intVal <= 2030) && !(intVal >= 2560 && intVal <= 2575)) {
              return val;
            }
          }
        }
      }
    }

    // 8. ตัวเลขจำนวนเต็มโดดๆ ในบรรทัด (Fallback สำหรับ K PLUS Theme เช่น "864", "10")
    for (final line in lines) {
      if (_isFeeLine(line)) continue;
      final trimmed = line.trim();
      // ข้ามถ้าเป็นเวลา เช่น 12:30, 09:15
      if (trimmed.contains(':')) continue;
      // ข้ามถ้าเป็นวันที่ เช่น 07/09/2026 หรือ 2026-09-07 หรือ 7-Eleven
      if (trimmed.contains('/') || trimmed.contains('-')) continue;

      final pureNumMatch = RegExp(r'^([0-9]{1,3}(?:,[0-9]{3})*|[1-9][0-9]{0,6})$').firstMatch(trimmed);
      if (pureNumMatch != null) {
        final clean = pureNumMatch.group(1)?.replaceAll(',', '');
        if (clean != null) {
          final val = double.tryParse(clean);
          if (val != null && val > 0 && val < 50000000) {
            final intVal = val.toInt();
            // ข้ามเลขปี พ.ศ. หรือ ค.ศ.
            if ((intVal >= 2020 && intVal <= 2030) || (intVal >= 2560 && intVal <= 2575)) {
              continue;
            }
            return val;
          }
        }
      }
    }

    return null;
  }

  static String? lastKnownSenderName;

  bool _isBankLine(String line) {
    final lower = line.toLowerCase().trim();
    if (BankType.detectFromText(lower) != null) return true;
    if (lower.contains('กสิกร') ||
        lower.contains('ไทยพาณิชย์') ||
        lower.contains('กรุงศรี') ||
        lower.contains('กรุงไทย') ||
        lower.contains('กรุงเทพ') ||
        lower.contains('ทหารไทย') ||
        lower.contains('ออมสิน') ||
        lower.contains('พร้อมเพย์') ||
        lower.contains('prompt') ||
        lower.contains('pay') ||
        lower.contains('promptpay') ||
        lower.contains('kbank') ||
        lower.contains('scb') ||
        lower.contains('ktb') ||
        lower.contains('bbl') ||
        lower.contains('ttb') ||
        lower.contains('bay') ||
        lower.contains('gsb') ||
        lower.contains('truemoney') ||
        lower.startsWith('ธ.') ||
        lower.startsWith('ธนาคาร')) {
      return true;
    }
    return false;
  }

  bool _isAccountLine(String line) {
    final trimmed = line.trim();
    if (RegExp(r'^[xX0-9\-\s]{6,}$').hasMatch(trimmed)) return true;
    if (RegExp(r'\b[xX0-9]{3,}-[xX0-9\-]+\b').hasMatch(trimmed)) return true;
    return false;
  }

  String _extractRecipient(List<String> lines, String fullText, BankType bank) {
    // 1. ตรวจสอบป้ายกำกับมาตรฐานในแต่ละบรรทัด
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      // 1.1 ไปยัง, โอนไปยัง, ส่งไปยัง, เข้าบัญชี
      if (line.startsWith('ไปยัง') ||
          line.startsWith('โอนไปยัง') ||
          line.startsWith('ส่งไปยัง') ||
          line.startsWith('เข้าบัญชี')) {
        var recipient = line.replaceFirst(
          RegExp(r'^(?:ไปยัง|โอนไปยัง|ส่งไปยัง|เข้าบัญชี)\s*[:]?\s*'),
          '',
        ).trim();
        if (recipient.isNotEmpty &&
            !_isGenericLabel(recipient) &&
            !_isBankLine(recipient) &&
            !_isAccountLine(recipient)) {
          return _cleanRecipient(recipient);
        }
        // สแกนบรรทัดถัดไป 1-4 บรรทัด ข้ามชื่อธนาคารและเลขบัญชี
        for (int j = i + 1; j < lines.length && j <= i + 4; j++) {
          final nextLine = lines[j].trim();
          if (nextLine.isEmpty ||
              _isGenericLabel(nextLine) ||
              _isBankLine(nextLine) ||
              _isAccountLine(nextLine)) {
            continue;
          }
          return _cleanRecipient(nextLine);
        }
      }

      // 1.2 ผู้รับเงิน, ผู้รับ, โอนให้, โอนเงินให้, ชำระให้, จ่ายให้, ร้านค้า
      if (line.startsWith('ผู้รับเงิน') ||
          line.startsWith('ชื่อผู้รับ') ||
          line.startsWith('ผู้รับ') ||
          line.startsWith('โอนให้') ||
          line.startsWith('โอนเงินให้') ||
          line.startsWith('โอนเข้า') ||
          line.startsWith('ชำระให้') ||
          line.startsWith('จ่ายให้') ||
          line.startsWith('ร้านค้า') ||
          line.startsWith('ชื่อร้านค้า')) {
        var recipient = line.replaceFirst(
          RegExp(r'^(?:ผู้รับเงิน|ชื่อผู้รับ(?:เงิน)?|ผู้รับ|โอนเงินให้|โอนให้|โอนเข้า|ชำระให้|จ่ายให้|ร้านค้า|ชื่อร้านค้า)\s*[:]?\s*'),
          '',
        ).trim();
        if (recipient.isNotEmpty &&
            !_isGenericLabel(recipient) &&
            !_isBankLine(recipient) &&
            !_isAccountLine(recipient)) {
          return _cleanRecipient(recipient);
        }
        for (int j = i + 1; j < lines.length && j <= i + 4; j++) {
          final nextLine = lines[j].trim();
          if (nextLine.isEmpty ||
              _isGenericLabel(nextLine) ||
              _isBankLine(nextLine) ||
              _isAccountLine(nextLine)) {
            continue;
          }
          return _cleanRecipient(nextLine);
        }
      }

      // 1.3 ชำระเงิน (เช่น "ชำระเงิน 7-Eleven(Thailand)" สำหรับ TrueMoney / บิลชำระค่าสินค้า)
      if (line.startsWith('ชำระเงิน') &&
          !line.contains('ช่องทาง') &&
          !line.contains('สำเร็จ') &&
          !line.contains('เสร็จสิ้น') &&
          !line.contains('ทั้งหมด') &&
          !line.contains('สุทธิ') &&
          !line.contains('ยอด')) {
        var recipient = line.replaceFirst(RegExp(r'^ชำระเงิน\s*[:]?\s*'), '').trim();
        if (recipient.isNotEmpty &&
            !_isGenericLabel(recipient) &&
            !_isBankLine(recipient) &&
            !_isAccountLine(recipient)) {
          return _cleanRecipient(recipient);
        }
        for (int j = i + 1; j < lines.length && j <= i + 4; j++) {
          final nextLine = lines[j].trim();
          if (nextLine.isEmpty ||
              _isGenericLabel(nextLine) ||
              _isBankLine(nextLine) ||
              _isAccountLine(nextLine)) {
            continue;
          }
          return _cleanRecipient(nextLine);
        }
      }

      // 1.4 To / Receiver
      if (line.toLowerCase() == 'to' || line.toLowerCase().startsWith('to:')) {
        var recipient = line.replaceFirst(RegExp(r'^to\s*[:]?\s*', caseSensitive: false), '').trim();
        if (recipient.isNotEmpty &&
            !_isGenericLabel(recipient) &&
            !_isBankLine(recipient) &&
            !_isAccountLine(recipient)) {
          return _cleanRecipient(recipient);
        }
        for (int j = i + 1; j < lines.length && j <= i + 4; j++) {
          final nextLine = lines[j].trim();
          if (nextLine.isEmpty ||
              _isGenericLabel(nextLine) ||
              _isBankLine(nextLine) ||
              _isAccountLine(nextLine)) {
            continue;
          }
          return _cleanRecipient(nextLine);
        }
      }
    }

    // 2. กรณี TrueMoney หรือสลิปร้านค้า ที่มีชื่อร้านค้าหรือผู้รับอยู่แถวบนสุด (เช่น "เซเว่น อีเลฟเว่น")
    if (bank == BankType.truemoney) {
      for (int i = 0; i < lines.length && i < 4; i++) {
        final line = lines[i].trim();
        final lower = line.toLowerCase();
        if (lower.isEmpty ||
            lower.contains('truemoney') ||
            lower.contains('ทรูมันนี่') ||
            lower.contains('วอลเล็ท') ||
            lower.contains('wallet') ||
            lower.contains('฿') ||
            lower.contains('thb') ||
            lower.contains('บาท') ||
            lower.contains('สำเร็จ') ||
            _isGenericLabel(line)) {
          continue;
        }
        if (line.length >= 2 && !RegExp(r'^[0-9:\./\-]+$').hasMatch(line)) {
          return _cleanRecipient(line);
        }
      }
    }

    // 3. สำหรับสลิป 2 ฝั่ง (เช่น K PLUS / SCB) ที่ไม่มีคำว่า "ไปยัง"
    // ค้นหาชื่อผู้รับจากบรรทัดที่อยู่ใต้ธนาคาร/เลขบัญชีของผู้โอน
    final firstBankIdx = lines.indexWhere(_isBankLine);
    if (firstBankIdx != -1) {
      for (int i = firstBankIdx + 1; i < lines.length && i <= firstBankIdx + 7; i++) {
        final line = lines[i].trim();
        if (line.isEmpty ||
            _isGenericLabel(line) ||
            _isBankLine(line) ||
            _isAccountLine(line) ||
            line.contains(':') ||
            line.contains('สำเร็จ') ||
            line.contains('บาท') ||
            (lastKnownSenderName != null &&
                lastKnownSenderName!.isNotEmpty &&
                (line == lastKnownSenderName || line.contains(lastKnownSenderName!)))) {
          continue;
        }
        if (line.length >= 2 && RegExp(r'[a-zA-Z\u0E00-\u0E7F]').hasMatch(line)) {
          return _cleanRecipient(line);
        }
      }
    }

    return '';
  }

  String _extractSender(List<String> lines, String fullText) {
    // 1. ตรวจสอบตามคำค้นหาชัดเจน เช่น "จาก", "ผู้โอน", "โอนจาก", "from:"
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.startsWith('จาก') ||
          line.startsWith('ผู้โอน') ||
          line.startsWith('โอนจาก') ||
          line.toLowerCase().startsWith('from:')) {
        var sender = line.replaceFirst(
          RegExp(r'^(?:จาก|ผู้โอน|โอนจาก|from:)\s*[:]?\s*', caseSensitive: false),
          '',
        ).trim();
        if (sender.isNotEmpty &&
            !_isGenericLabel(sender) &&
            !_isBankLine(sender) &&
            !_isAccountLine(sender)) {
          final cleaned = _cleanRecipient(sender);
          lastKnownSenderName = cleaned;
          return cleaned;
        }
        for (int j = i + 1; j < lines.length && j <= i + 4; j++) {
          final nextLine = lines[j].trim();
          if (nextLine.isEmpty ||
              _isGenericLabel(nextLine) ||
              _isBankLine(nextLine) ||
              _isAccountLine(nextLine)) {
            continue;
          }
          final cleaned = _cleanRecipient(nextLine);
          lastKnownSenderName = cleaned;
          return cleaned;
        }
      }
    }

    // 2. สำหรับ KBank K PLUS (สลิปไม่มีคำว่า "จาก" แต่ชื่อผู้โอนจะอยู่ใต้ วันที่/เวลา และอยู่เหนือ "ไปยัง")
    int toIndex = -1;
    for (int i = 0; i < lines.length; i++) {
      if (lines[i].trim().startsWith('ไปยัง') ||
          lines[i].trim().toLowerCase().startsWith('to:')) {
        toIndex = i;
        break;
      }
    }
    if (toIndex > 0) {
      for (int i = 0; i < toIndex; i++) {
        final line = lines[i].trim();
        if (line.isEmpty ||
            line.contains('สำเร็จ') ||
            line.contains('โอนเงิน') ||
            line.contains(':') ||
            line.contains('/') ||
            _isGenericLabel(line) ||
            _isBankLine(line) ||
            _isAccountLine(line)) {
          continue;
        }
        if (line.length >= 3 && RegExp(r'[a-zA-Z\u0E00-\u0E7F]').hasMatch(line)) {
          final cleaned = _cleanRecipient(line);
          lastKnownSenderName = cleaned;
          return cleaned;
        }
      }
    }

    // 3. หากไม่มี "จาก" และไม่มี "ไปยัง" (เช่น K PLUS)
    // ชื่อผู้โอนจะอยู่เหนือบรรทัดชื่อธนาคารบรรทัดแรก
    final firstBankIdx = lines.indexWhere(_isBankLine);
    if (firstBankIdx > 0) {
      for (int i = 0; i < firstBankIdx; i++) {
        final line = lines[i].trim();
        if (line.isEmpty ||
            line.contains('สำเร็จ') ||
            line.contains('โอนเงิน') ||
            line.contains(':') ||
            line.contains('/') ||
            _isGenericLabel(line) ||
            _isBankLine(line) ||
            _isAccountLine(line)) {
          continue;
        }
        if (line.length >= 3 && RegExp(r'[a-zA-Z\u0E00-\u0E7F]').hasMatch(line)) {
          final cleaned = _cleanRecipient(line);
          lastKnownSenderName = cleaned;
          return cleaned;
        }
      }
    }

    return lastKnownSenderName ?? '';
  }

  bool _isGenericLabel(String line) {
    final lower = line.toLowerCase().trim();
    return lower.contains('จำนวนเงิน') ||
        lower.contains('amount') ||
        lower.contains('วันที่') ||
        lower.contains('date') ||
        lower.contains('รหัสอ้างอิง') ||
        lower.contains('เลขที่รายการ') ||
        lower.contains('เลขที่อ้างอิง') ||
        lower.contains('ref') ||
        lower.contains('บาท') ||
        lower.contains('ช่องทาง') ||
        lower.contains('สำเร็จ') ||
        lower.contains('เสร็จสิ้น') ||
        lower.contains('วอลเล็ท') ||
        lower.contains('wallet') ||
        lower.contains('ยอดชำระ') ||
        lower.contains('ค่าธรรมเนียม') ||
        lower.contains('fee') ||
        lower.contains('prompt') ||
        lower.contains('พร้อมเพย์') ||
        lower.contains('รหัสพร้อมเพย์') ||
        lower.contains('หมายเลขพร้อมเพย์') ||
        lower.contains('สแกนตรวจสอบสลิป') ||
        lower.contains('ตรวจสอบสลิป') ||
        lower.contains('ตรวจสอบ') ||
        lower == 'pay' ||
        lower == 'to' ||
        lower == 'from' ||
        lower.startsWith('to:') ||
        lower.startsWith('from:') ||
        lower.length < 2;
  }

  String _cleanRecipient(String name) {
    // ตัดเลขบัญชี xxx-xxx หรือคำนำหน้าส่วนเกิน
    var clean = name.replaceAll(RegExp(r'\b[xX0-9\-]{6,}\b'), '').trim();
    if (clean.length > 40) {
      clean = clean.substring(0, 40).trim();
    }
    final lower = clean.toLowerCase();
    if (lower == 'prompt' ||
        lower == 'pay' ||
        lower == 'promptpay' ||
        lower == 'พร้อมเพย์' ||
        lower == 'รหัสพร้อมเพย์') {
      return '';
    }
    return clean;
  }

  BankType? _extractDestinationBank(List<String> lines, String fullText, BankType sourceBank) {
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      final lower = line.toLowerCase();
      if (lower.startsWith('ไปยัง') ||
          lower.startsWith('โอนไปยัง') ||
          lower.startsWith('ส่งไปยัง') ||
          lower.startsWith('เข้าบัญชี') ||
          lower.startsWith('ธนาคารผู้รับ') ||
          lower.startsWith('ผู้รับเงิน') ||
          lower.startsWith('to:') ||
          lower.startsWith('to ')) {
        for (int j = i; j <= i + 4 && j < lines.length; j++) {
          final targetLine = lines[j];
          final detected = BankType.detectFromText(targetLine);
          if (detected != null) {
            return detected;
          }
        }
      }
    }

    // หากไม่พบจากคำว่า "ไปยัง" ให้หาชื่อธนาคารอื่นที่ไม่ใช่ sourceBank ในสลิป
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      final detected = BankType.detectFromText(line);
      if (detected != null && detected != sourceBank) {
        return detected;
      }
    }

    return null;
  }

  /// แปลงพยัญชนะไทยเป็นชุดรหัสเสียงพยัญชนะสากล (Generic Thai Phonetic Tokens)
  static List<String> _thaiToPhoneticTokens(String s) {
    // ตัดการันต์และตัวอักษรที่อยู่ใต้การันต์ (ตัวการันต์จะไม่ออกเสียง เช่น พงษ์ -> พง, สิทธิ์ -> สิท)
    final normalized = s.replaceAll(RegExp(r'[\u0E00-\u0E7F]\u0E4C'), '');
    final tokens = <String>[];
    for (int i = 0; i < normalized.length; i++) {
      final c = normalized[i];
      switch (c) {
        case 'ก':
        case 'ข': case 'ฃ': case 'ค': case 'ฅ': case 'ฆ':
          tokens.add('k');
          break;
        case 'ง':
          tokens.add('ng');
          break;
        case 'จ': case 'ฉ': case 'ช': case 'ฌ':
          tokens.add('ch');
          break;
        case 'ซ': case 'ศ': case 'ษ': case 'ส':
          tokens.add('s');
          break;
        case 'ญ': case 'ย':
          tokens.add('y');
          break;
        case 'ด': case 'ฎ':
          tokens.add('d');
          break;
        case 'ต': case 'ฏ':
        case 'ถ': case 'ฐ': case 'ท': case 'ฑ': case 'ธ': case 'ฒ':
          tokens.add('t');
          break;
        case 'น': case 'ณ':
          tokens.add('n');
          break;
        case 'บ':
          tokens.add('b');
          break;
        case 'ป':
        case 'ผ': case 'พ': case 'ภ':
          tokens.add('p');
          break;
        case 'ฝ': case 'ฟ':
          tokens.add('f');
          break;
        case 'ม':
          tokens.add('m');
          break;
        case 'ร':
          tokens.add('r');
          break;
        case 'ล': case 'ฬ':
          tokens.add('l');
          break;
        case 'ว':
          tokens.add('w');
          break;
        case 'ห': case 'ฮ':
          tokens.add('h');
          break;
        default:
          break;
      }
    }
    return tokens;
  }

  /// แปลงพยัญชนะภาษาอังกฤษตามการสะกดชื่อไทยเป็นชุดรหัสเสียงพยัญชนะ (Generic English Phonetic Tokens)
  static List<String> _englishToPhoneticTokens(String s) {
    final lower = s.toLowerCase().trim();
    final tokens = <String>[];
    int i = 0;
    while (i < lower.length) {
      // ตรวจสอบเสียง 2 ตัวอักษร
      if (i + 1 < lower.length) {
        final pair = lower.substring(i, i + 2);
        if (pair == 'ng') {
          tokens.add('ng');
          i += 2;
          continue;
        } else if (pair == 'ch' || pair == 'sh') {
          tokens.add('ch');
          i += 2;
          continue;
        } else if (pair == 'kh' || pair == 'ck') {
          tokens.add('k');
          i += 2;
          continue;
        } else if (pair == 'ph') {
          tokens.add('p');
          i += 2;
          continue;
        } else if (pair == 'th') {
          tokens.add('t');
          i += 2;
          continue;
        }
      }

      // ตรวจสอบเสียง 1 ตัวอักษร
      final c = lower[i];
      switch (c) {
        case 'k': case 'c': case 'q': case 'g':
          tokens.add('k');
          break;
        case 'j':
          tokens.add('ch');
          break;
        case 's': case 'z': case 'x':
          tokens.add('s');
          break;
        case 't':
          tokens.add('t');
          break;
        case 'd':
          tokens.add('d');
          break;
        case 'p':
          tokens.add('p');
          break;
        case 'b':
          tokens.add('b');
          break;
        case 'm':
          tokens.add('m');
          break;
        case 'n':
          tokens.add('n');
          break;
        case 'r':
          tokens.add('r');
          break;
        case 'l':
          tokens.add('l');
          break;
        case 'w': case 'v':
          tokens.add('w');
          break;
        case 'f':
          tokens.add('f');
          break;
        case 'h':
          tokens.add('h');
          break;
        case 'y':
          tokens.add('y');
          break;
        default:
          break;
      }
      i++;
    }
    return tokens;
  }

  /// ตรวจสอบว่าชุดรหัสเสียงพยัญชนะตรงกันหรือไม่
  static bool _phoneticTokenMatch(List<String> a, List<String> b) {
    if (a.isEmpty || b.isEmpty) return false;
    final strA = a.join('-');
    final strB = b.join('-');
    if (strA == strB) return true;

    // เปรียบเทียบตัวขึ้นต้น (เช่น สมชาย: s-m-ch ตรงกับ SOMCHAI: s-m-ch)
    final minLen = a.length < b.length ? a.length : b.length;
    if (minLen >= 2) {
      bool prefixMatch = true;
      for (int i = 0; i < minLen; i++) {
        if (a[i] != b[i]) {
          prefixMatch = false;
          break;
        }
      }
      if (prefixMatch) return true;
    }
    return false;
  }

  /// เปรียบเทียบชื่อไทยกับภาษาอังกฤษแบบอัลกอริทึมทั่วไป (Generic Bilingual Matching สำหรับระบบ SaaS)
  static bool _isBilingualPhoneticMatch(String nameA, String nameB) {
    final hasThaiA = RegExp(r'[\u0E00-\u0E7F]').hasMatch(nameA);
    final hasThaiB = RegExp(r'[\u0E00-\u0E7F]').hasMatch(nameB);
    final hasLatinA = RegExp(r'[a-zA-Z]').hasMatch(nameA);
    final hasLatinB = RegExp(r'[a-zA-Z]').hasMatch(nameB);

    if (!((hasThaiA && hasLatinB) || (hasLatinA && hasThaiB))) {
      return false;
    }

    final thaiName = hasThaiA ? nameA : nameB;
    final englishName = hasLatinB ? nameB : nameA;

    final thaiTokens = thaiName.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    final engTokens = englishName.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();

    if (thaiTokens.isEmpty || engTokens.isEmpty) return false;

    // 1. เปรียบเทียบชื่อจริงตัวแรก (First Name)
    final thaiFirst = _thaiToPhoneticTokens(thaiTokens.first);
    final engFirst = _englishToPhoneticTokens(engTokens.first);
    if (_phoneticTokenMatch(thaiFirst, engFirst)) {
      return true;
    }

    // 2. เปรียบเทียบทั้งชื่อเต็ม (Full Name)
    final thaiAll = _thaiToPhoneticTokens(thaiName);
    final engAll = _englishToPhoneticTokens(englishName);
    if (_phoneticTokenMatch(thaiAll, engAll)) {
      return true;
    }

    return false;
  }

  static bool isSamePersonName(String nameA, String nameB) {
    String clean(String s) {
      var trimmed = s.toLowerCase().trim();
      trimmed = trimmed.replaceFirst(
        RegExp(r'^(?:นาย|นางสาว|นาง|น\.ส\.|ด\.ช\.|ด\.ญ\.|mr\.|mrs\.|ms\.|miss|khun|คุณ)\s*'),
        '',
      );
      trimmed = trimmed.replaceAll(RegExp(r'\s+[a-z\u0E00-\u0E7F]\.?$'), '').trim();
      return trimmed;
    }

    final cA = clean(nameA);
    final cB = clean(nameB);
    if (cA.isEmpty || cB.isEmpty) return false;

    final lettersA = cA.replaceAll(RegExp(r'[^a-zA-Z\u0E00-\u0E7F]'), '');
    final lettersB = cB.replaceAll(RegExp(r'[^a-zA-Z\u0E00-\u0E7F]'), '');
    if (lettersA.isEmpty || lettersB.isEmpty) return false;

    // 1. ตัวอักษรตรงกันทั้งหมด
    if (lettersA == lettersB) return true;

    // 2. ซ้อนกัน เช่น "สมชาย น." อยู่ใน "สมชาย นำโชค"
    if (lettersA.length >= 4 && (lettersB.contains(lettersA) || lettersA.contains(lettersB))) {
      return true;
    }

    // 3. ชื่อจริงคำแรกตรงกัน (ภาษาเดียวกัน)
    final firstA = cA.split(RegExp(r'\s+')).first.replaceAll(RegExp(r'[^a-zA-Z\u0E00-\u0E7F]'), '');
    final firstB = cB.split(RegExp(r'\s+')).first.replaceAll(RegExp(r'[^a-zA-Z\u0E00-\u0E7F]'), '');
    if (firstA.length >= 3 && firstA == firstB) {
      return true;
    }

    // 4. เปรียบเทียบชื่อไทยกับภาษาอังกฤษแบบทั่วไปด้วยระบบเสียงสากล (Generic Bilingual Matching)
    if (_isBilingualPhoneticMatch(cA, cB)) {
      return true;
    }

    return false;
  }

  bool _isSamePersonName(String nameA, String nameB) => isSamePersonName(nameA, nameB);

  bool _detectIsTransfer(
    List<String> lines,
    String fullText,
    String recipient,
    BankType? destinationBank, {
    String? knownOwnerName,
    String? recipientAccount,
    String? senderName,
  }) {
    final lower = fullText.toLowerCase();

    // 1. ตรวจสอบคีย์เวิร์ดบนสลิปของทุกธนาคาร (ทั้งภาษาไทยและอังกฤษ)
    final transferPhrases = [
      'โอนระหว่างบัญชีตนเอง',
      'โอนเงินระหว่างบัญชีตนเอง',
      'โอนระหว่างบัญชี',
      'โอนเงินระหว่างบัญชี',
      'เข้าบัญชีตนเอง',
      'บัญชีตัวเอง',
      'บัญชีตนเอง',
      'โอนเข้าบัญชีตัวเอง',
      'own account',
      'to own account',
      'my account',
      'transfer to own account',
      'own-account',
      'internal transfer',
      'ย้ายเงิน',
      'ย้ายเข้าบัญชี',
      'สลับบัญชี',
    ];
    for (final phrase in transferPhrases) {
      if (lower.contains(phrase)) return true;
    }

    // 2. ตรวจสอบคำในบันทึกช่วยจำ (Memo / Note)
    final memoKeywords = [
      'ย้ายเงิน', 'ย้าย', 'เงินเก็บ', 'เงินออม', 'เข้าบัญชีเก็บ', 'ฝากเก็บ',
      'transfer', 'savings', 'saving', 'own'
    ];
    for (final line in lines) {
      final lowerLine = line.toLowerCase();
      if (lowerLine.contains('บันทึก') || lowerLine.contains('memo') || lowerLine.contains('note')) {
        for (final kw in memoKeywords) {
          if (lowerLine.contains(kw)) return true;
        }
      }
    }

    // 3. เปรียบเทียบชื่อผู้โอนกับผู้รับโอน (ถ้ามีชื่อทั้งสองฝ่าย ถือเป็นหลักฐานชี้ขาดที่แม่นยำที่สุด!)
    final effectiveSender = (senderName != null && senderName.isNotEmpty)
        ? senderName
        : _extractSender(lines, fullText);
    if (effectiveSender.isNotEmpty && recipient.isNotEmpty) {
      if (_isSamePersonName(effectiveSender, recipient)) {
        return true;
      } else {
        // คนละคนกันชัดเจน (ผู้โอน != ผู้รับโอน) -> ถือเป็นรายจ่าย/โอนออก 100% ห้ามเป็นย้ายเงินเด็ดขาด!
        return false;
      }
    }

    // 4. ตรวจสอบกับข้อมูลบัญชีตนเองที่ระบบเคยเรียนรู้ไว้ (Learned Own Accounts & Names)
    // สำหรับกรณีที่สลิปไม่มีชื่อผู้โอน เช่น PromptPay หรือสลิปบางธนาคาร
    if (recipient.isNotEmpty) {
      for (final learnedName in learnedOwnNames) {
        if (_isSamePersonName(learnedName, recipient)) {
          return true;
        }
      }
    }
    if (recipientAccount != null && recipientAccount.isNotEmpty) {
      final cleanAcc = recipientAccount.replaceAll(RegExp(r'[^0-9]'), '');
      for (final learnedAcc in learnedOwnAccounts) {
        if (learnedAcc.length >= 4 && (cleanAcc.contains(learnedAcc) || learnedAcc.contains(cleanAcc))) {
          return true;
        }
      }
    }
    final rawNumbersOnly = fullText.replaceAll(RegExp(r'[^0-9]'), '');
    for (final learnedAcc in learnedOwnAccounts) {
      if (learnedAcc.length >= 4 && rawNumbersOnly.contains(learnedAcc)) {
        return true;
      }
    }

    // 5. ตรวจสอบกับชื่อเจ้าของที่บันทึกไว้ในระบบ (SaaS User Profile Name)
    final effectiveOwnerName = (knownOwnerName != null && knownOwnerName.trim().isNotEmpty)
        ? knownOwnerName.trim()
        : (AuthSession.displayName?.trim().isNotEmpty == true ? AuthSession.displayName!.trim() : null);

    if (effectiveOwnerName != null && recipient.isNotEmpty) {
      if (_isSamePersonName(effectiveOwnerName, recipient)) {
        return true;
      }
    }

    return false;
  }

  DateTime? _extractDate(List<String> lines, String fullText) {
    // 1. ตรวจสอบรูปแบบภาษาไทย เช่น 05 ก.ย. 2569 14:30 น.
    final thaiMonthMap = {
      'ม.ค.': 1, 'ก.พ.': 2, 'มี.ค.': 3, 'เม.ย.': 4,
      'พ.ค.': 5, 'มิ.ย.': 6, 'ก.ค.': 7, 'ส.ค.': 8,
      'ก.ย.': 9, 'ต.ค.': 10, 'พ.ย.': 11, 'ธ.ค.': 12,
      'ม.ค': 1, 'ก.พ': 2, 'มี.ค': 3, 'เม.ย': 4,
      'พ.ค': 5, 'มิ.ย': 6, 'ก.ค': 7, 'ส.ค': 8,
      'ก.ย': 9, 'ต.ค': 10, 'พ.ย': 11, 'ธ.ค': 12,
    };

    for (var entry in thaiMonthMap.entries) {
      final regex = RegExp(
        '(\\d{1,2})\\s*${RegExp.escape(entry.key)}\\.?\\s*(\\d{2,4})(?:\\s*[,]?\\s*(\\d{1,2}):(\\d{2}))?',
      );
      final match = regex.firstMatch(fullText);
      if (match != null) {
        final day = int.tryParse(match.group(1) ?? '') ?? 1;
        var year = int.tryParse(match.group(2) ?? '') ?? DateTime.now().year;
        // หากเป็น พ.ศ. (มากกว่า 2500) ให้แปลงเป็น ค.ศ.
        if (year > 2400) {
          year -= 543;
        } else if (year < 100) {
          // เช่น 69 -> 2026
          year = 2000 + year - 43;
        }
        final hour = int.tryParse(match.group(3) ?? '') ?? 12;
        final minute = int.tryParse(match.group(4) ?? '') ?? 0;
        return _buildThaiSlipDateTime(year, entry.value, day, hour, minute);
      }
    }

    // 2. ตรวจสอบรูปแบบภาษาอังกฤษ เช่น 05 Sep 2026, 14:30
    final englishMonthMap = {
      'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
      'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
    };
    final engRegex = RegExp(
      r'(\d{1,2})\s+([A-Za-z]{3,9})\.?\s+(\d{2,4})(?:\s*[,]?\s*(\d{1,2}):(\d{2}))?',
      caseSensitive: false,
    );
    final engMatch = engRegex.firstMatch(fullText);
    if (engMatch != null) {
      final day = int.tryParse(engMatch.group(1) ?? '') ?? 1;
      final mKey = (engMatch.group(2) ?? '').toLowerCase();
      final month = englishMonthMap.entries
          .firstWhere(
            (e) => mKey.startsWith(e.key),
            orElse: () => const MapEntry('', 0),
          )
          .value;
      if (month > 0) {
        var year = int.tryParse(engMatch.group(3) ?? '') ?? DateTime.now().year;
        if (year < 100) year += 2000;
        final hour = int.tryParse(engMatch.group(4) ?? '') ?? 12;
        final minute = int.tryParse(engMatch.group(5) ?? '') ?? 0;
        return _buildThaiSlipDateTime(year, month, day, hour, minute);
      }
    }

    // 3. รูปแบบ dd/MM/yyyy
    final slashRegex = RegExp(r'(\d{1,2})/(\d{1,2})/(\d{4})\s*(?:(\d{1,2}):(\d{2}))?');
    final slashMatch = slashRegex.firstMatch(fullText);
    if (slashMatch != null) {
      final day = int.tryParse(slashMatch.group(1) ?? '') ?? 1;
      final month = int.tryParse(slashMatch.group(2) ?? '') ?? 1;
      var year = int.tryParse(slashMatch.group(3) ?? '') ?? DateTime.now().year;
      if (year > 2400) year -= 543;
      final hour = int.tryParse(slashMatch.group(4) ?? '') ?? 12;
      final minute = int.tryParse(slashMatch.group(5) ?? '') ?? 0;
      return _buildThaiSlipDateTime(year, month, day, hour, minute);
    }

    return null;
  }

  DateTime _buildThaiSlipDateTime(int year, int month, int day, int hour, int minute) {
    // เวลาบนสลิปธนาคารไทยเป็นเวลาประเทศไทย (ICT / UTC+7) เสมอ
    // แปลงเป็น UTC ที่แน่นอน (ลบ 7 ชม.) แล้วคืนค่ากลับเป็น Local time
    // เพื่อให้ .toUtc() คืนค่าเวลาสากลที่แท้จริง ไม่เกิดปัญหาข้ามวันเมื่อส่งขึ้นเซิร์ฟเวอร์
    final utc = DateTime.utc(year, month, day, hour, minute).subtract(const Duration(hours: 7));
    return utc.toLocal();
  }

  String? _extractReferenceNo(List<String> lines, String fullText) {
    final regex = RegExp(
      r'(?:รหัสอ้างอิง|เลขที่รายการ|Transaction ID|Ref\.?\s*(?:No\.?)?)\s*[:]?\s*([A-Za-z0-9\-]+)',
      caseSensitive: false,
    );
    final match = regex.firstMatch(fullText);
    if (match != null) {
      return match.group(1)?.trim();
    }
    return null;
  }
}
