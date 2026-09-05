enum BankType {
  kbank,
  scb,
  krungsri,
  other;

  String get displayName {
    switch (this) {
      case BankType.kbank:
        return 'กสิกรไทย (KBank)';
      case BankType.scb:
        return 'ไทยพาณิชย์ (SCB)';
      case BankType.krungsri:
        return 'กรุงศรี (BAY)';
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
      case BankType.other:
        return 0xFF00A88F;
    }
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
  bool isSelected;

  ParsedSlip({
    required this.id,
    required this.bank,
    required this.amount,
    required this.recipient,
    required this.date,
    this.referenceNo,
    required this.rawText,
    this.isSelected = true,
  });

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
  }) {
    if (lines.isEmpty && fullText.trim().isEmpty) return null;

    final lower = fullText.toLowerCase();

    // 1. ระบุธนาคาร
    final bank = _detectBank(lower);

    // 2. ดึงยอดเงิน (Amount)
    final amount = _extractAmount(lines, fullText);
    if (amount == null || amount <= 0) {
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
    );
  }

  BankType _detectBank(String lower) {
    if (lower.contains('กสิกรไทย') || lower.contains('kbank') || lower.contains('k plus') || lower.contains('kbiz')) {
      return BankType.kbank;
    }
    if (lower.contains('ไทยพาณิชย์') || lower.contains('scb') || lower.contains('easy')) {
      return BankType.scb;
    }
    if (lower.contains('กรุงศรี') || lower.contains('krungsri') || lower.contains('kma') || lower.contains('bay')) {
      return BankType.krungsri;
    }
    return BankType.other;
  }

  double? _extractAmount(List<String> lines, String fullText) {
    // Pattern 1: บรรทัดเดียวกัน เช่น "จำนวนเงิน: 1,500.00 บาท" หรือ "Amount 120.00"
    final regexSameLine = RegExp(
      r'(?:จำนวนเงิน|จํานวนเงิน|ยอดเงิน|Amount|ยอดโอน|จำนวน)\s*[:]?\s*([0-9,]+\.[0-9]{2})',
      caseSensitive: false,
    );

    final match = regexSameLine.firstMatch(fullText);
    if (match != null) {
      final clean = match.group(1)?.replaceAll(',', '');
      if (clean != null) {
        final val = double.tryParse(clean);
        if (val != null && val > 0) return val;
      }
    }

    // Pattern 2: คำว่า "จำนวนเงิน" อยู่คนละบรรทัดกับตัวเลขยอดเงิน (พบบ่อยใน Vision OCR)
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      final isAmountLabel = line == 'จำนวนเงิน' ||
          line == 'จํานวนเงิน' ||
          line.startsWith('จำนวนเงิน') ||
          line.startsWith('จํานวนเงิน') ||
          line.toLowerCase() == 'amount';

      if (isAmountLabel && i + 1 < lines.length) {
        final nextLine = lines[i + 1].trim();
        final amountMatch = RegExp(r'([0-9,]+\.[0-9]{2})').firstMatch(nextLine);
        if (amountMatch != null) {
          final clean = amountMatch.group(1)?.replaceAll(',', '');
          if (clean != null) {
            final val = double.tryParse(clean);
            if (val != null && val > 0) return val;
          }
        }
      }
    }

    // Pattern 3: สแกนหาตัวเลขทศนิยม 2 ตำแหน่งที่มีสัญลักษณ์ บาท / Baht / THB อยู่ข้างๆ
    final regexCurrency = RegExp(r'([0-9,]+\.[0-9]{2})\s*(?:บาท|baht|thb)', caseSensitive: false);
    final currencyMatch = regexCurrency.firstMatch(fullText);
    if (currencyMatch != null) {
      final clean = currencyMatch.group(1)?.replaceAll(',', '');
      if (clean != null) {
        final val = double.tryParse(clean);
        if (val != null && val > 0) return val;
      }
    }

    return null;
  }

  String _extractRecipient(List<String> lines, String fullText, BankType bank) {
    // มองหาบรรทัดที่บอกว่า "ไปยัง" หรือ "To"
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();

      // บรรทัดที่มีคำว่า "ไปยัง" นำหน้า
      if (line.startsWith('ไปยัง') || line.startsWith('โอนไปยัง')) {
        var recipient = line.replaceFirst(RegExp(r'^(?:ไปยัง|โอนไปยัง)\s*[:]?\s*'), '').trim();
        if (recipient.isNotEmpty && !_isGenericLabel(recipient)) {
          return _cleanRecipient(recipient);
        }
        // ถ้าบรรทัดนี้มีแค่คำว่า "ไปยัง" ให้ดูบรรทัดถัดไป
        if (i + 1 < lines.length) {
          final nextLine = lines[i + 1].trim();
          if (!_isGenericLabel(nextLine)) {
            return _cleanRecipient(nextLine);
          }
        }
      }

      if (line.toLowerCase() == 'to' && i + 1 < lines.length) {
        final nextLine = lines[i + 1].trim();
        if (!_isGenericLabel(nextLine)) {
          return _cleanRecipient(nextLine);
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
    // ตัวอย่างรูปแบบวันที่ในสลิปไทย:
    // 05 ก.ย. 2569 14:30 น.
    // 05/09/2026 14:30
    // 2026-09-05
    final thaiMonthMap = {
      'ม.ค.': 1, 'ก.พ.': 2, 'มี.ค.': 3, 'เม.ย.': 4,
      'พ.ค.': 5, 'มิ.ย.': 6, 'ก.ค.': 7, 'ส.ค.': 8,
      'ก.ย.': 9, 'ต.ค.': 10, 'พ.ย.': 11, 'ธ.ค.': 12,
    };

    for (var entry in thaiMonthMap.entries) {
      final regex = RegExp(
        '(\\d{1,2})\\s*${RegExp.escape(entry.key)}\\s*(\\d{2,4})(?:\\s*[,]?\\s*(\\d{1,2}):(\\d{2}))?',
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
        return DateTime(year, entry.value, day, hour, minute);
      }
    }

    // รูปแบบ dd/MM/yyyy
    final slashRegex = RegExp(r'(\d{1,2})/(\d{1,2})/(\d{4})\s*(?:(\d{1,2}):(\d{2}))?');
    final slashMatch = slashRegex.firstMatch(fullText);
    if (slashMatch != null) {
      final day = int.tryParse(slashMatch.group(1) ?? '') ?? 1;
      final month = int.tryParse(slashMatch.group(2) ?? '') ?? 1;
      var year = int.tryParse(slashMatch.group(3) ?? '') ?? DateTime.now().year;
      if (year > 2400) year -= 543;
      final hour = int.tryParse(slashMatch.group(4) ?? '') ?? 12;
      final minute = int.tryParse(slashMatch.group(5) ?? '') ?? 0;
      return DateTime(year, month, day, hour, minute);
    }

    return null;
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
