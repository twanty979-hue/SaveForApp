import 'package:flutter/foundation.dart';

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
    if (lower.contains('สลิป') || lower.contains('slip') || lower.contains('พร้อมเพย์') || lower.contains('promptpay')) {
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
  final DateTime date;
  final String? referenceNo;
  final String rawText;
  final String? imagePath;
  final String? albumName;
  bool isSelected;
  String? customNote;
  bool includeRecipientInNote;

  ParsedSlip({
    required this.id,
    required this.bank,
    required this.amount,
    required this.recipient,
    required this.date,
    this.referenceNo,
    required this.rawText,
    this.imagePath,
    this.albumName,
    this.isSelected = true,
    this.customNote,
    this.includeRecipientInNote = true,
  });

  /// ชื่อที่จะนำไปแสดงผลบนหน้าจอ
  String get displayTitle {
    if (customNote != null && customNote!.trim().isNotEmpty) {
      return customNote!.trim();
    }
    return recipient;
  }

  /// ข้อความชื่อรายการสำหรับบันทึกลงฐานข้อมูล
  String get finalFormattedNoteTitle {
    final custom = customNote?.trim();
    if (custom != null && custom.isNotEmpty) {
      if (includeRecipientInNote && recipient.trim().isNotEmpty) {
        return '$custom (โอนให้: ${recipient.trim()})';
      }
      return custom;
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

  /// ตรวจสอบและสกัดข้อมูลสลิปจากข้อความ OCR
  ParsedSlip? parse({
    required String id,
    required List<String> lines,
    required String fullText,
    DateTime? fallbackDate,
    String? imagePath,
    String? albumName,
  }) {
    if (lines.isEmpty && fullText.trim().isEmpty) return null;

    final lower = fullText.toLowerCase();

    // 1. ระบุธนาคาร
    final bank = _detectBank(lower);

    // 2. ดึงยอดเงิน (Amount)
    final amount = _extractAmount(lines, fullText);
    debugPrint('[SlipParser] Parsing id: $id, lines: ${lines.length}, detected bank: ${bank.name}, amount: $amount');

    if (amount == null || amount <= 0) {
      debugPrint('[SlipParser] Discarded slip: amount could not be extracted or <= 0');
      return null;
    }

    // 3. ดึงชื่อผู้รับโอน (Recipient)
    final recipient = _extractRecipient(lines, fullText, bank);

    // 4. ดึงวันที่ทำรายการ
    final date = _extractDate(lines, fullText) ?? fallbackDate ?? DateTime.now();

    // 5. ดึงรหัสอ้างอิง
    final ref = _extractReferenceNo(lines, fullText);

    return ParsedSlip(
      id: id,
      bank: bank,
      amount: amount,
      recipient: recipient.isNotEmpty ? recipient : 'โอนเงิน (${bank.displayName})',
      date: date,
      referenceNo: ref,
      rawText: fullText,
      imagePath: imagePath,
      albumName: albumName,
    );
  }

  BankType _detectBank(String lower) {
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

  String _extractRecipient(List<String> lines, String fullText, BankType bank) {
    // 1. ตรวจสอบป้ายกำกับมาตรฐานในแต่ละบรรทัด
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      // 1.1 ไปยัง, โอนไปยัง, ส่งไปยัง
      if (line.startsWith('ไปยัง') || line.startsWith('โอนไปยัง') || line.startsWith('ส่งไปยัง')) {
        var recipient = line.replaceFirst(RegExp(r'^(?:ไปยัง|โอนไปยัง|ส่งไปยัง)\s*[:]?\s*'), '').trim();
        if (recipient.isNotEmpty && !_isGenericLabel(recipient)) {
          return _cleanRecipient(recipient);
        }
        if (i + 1 < lines.length) {
          final nextLine = lines[i + 1].trim();
          if (!_isGenericLabel(nextLine)) {
            return _cleanRecipient(nextLine);
          }
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
        if (recipient.isNotEmpty && !_isGenericLabel(recipient)) {
          return _cleanRecipient(recipient);
        }
        if (i + 1 < lines.length) {
          final nextLine = lines[i + 1].trim();
          if (!_isGenericLabel(nextLine)) {
            return _cleanRecipient(nextLine);
          }
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
        if (recipient.isNotEmpty && !_isGenericLabel(recipient)) {
          return _cleanRecipient(recipient);
        }
        if (i + 1 < lines.length) {
          final nextLine = lines[i + 1].trim();
          if (!_isGenericLabel(nextLine)) {
            return _cleanRecipient(nextLine);
          }
        }
      }

      // 1.4 To / Receiver
      if (line.toLowerCase() == 'to' || line.toLowerCase().startsWith('to:')) {
        var recipient = line.replaceFirst(RegExp(r'^to\s*[:]?\s*', caseSensitive: false), '').trim();
        if (recipient.isNotEmpty && !_isGenericLabel(recipient)) {
          return _cleanRecipient(recipient);
        }
        if (i + 1 < lines.length) {
          final nextLine = lines[i + 1].trim();
          if (!_isGenericLabel(nextLine)) {
            return _cleanRecipient(nextLine);
          }
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

    return '';
  }

  bool _isGenericLabel(String line) {
    final lower = line.toLowerCase();
    return lower.contains('จำนวนเงิน') ||
        lower.contains('amount') ||
        lower.contains('วันที่') ||
        lower.contains('date') ||
        lower.contains('รหัสอ้างอิง') ||
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
        lower.length < 2;
  }

  String _cleanRecipient(String name) {
    // ตัดเลขบัญชี xxx-xxx หรือคำนำหน้าส่วนเกิน
    var clean = name.replaceAll(RegExp(r'\b[xX0-9\-]{8,}\b'), '').trim();
    if (clean.length > 40) {
      clean = clean.substring(0, 40).trim();
    }
    return clean;
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
