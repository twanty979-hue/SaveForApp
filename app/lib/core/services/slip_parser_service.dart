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
    return BankType.other;
  }

  double? _extractAmount(List<String> lines, String fullText) {
    // Pattern 1: บรรทัดเดียวกัน เช่น "จำนวนเงิน: 1,500.00 บาท" หรือ "Amount 120.00"
    final regexSameLine = RegExp(
      r'(?:จำนวนเงิน|จํานวนเงิน|ยอดเงิน|Amount|ยอดโอน|จำนวน|ยอดชำระ|ชำระเงิน)\s*[:]?\s*(?:THB|฿|บาท)?\s*([0-9,]+\.[0-9]{2})',
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

    // Pattern 2: คำว่า "จำนวนเงิน" อยู่คนละบรรทัดกับตัวเลขยอดเงิน (พบบ่อยใน K PLUS และ Vision OCR)
    // รองรับกรณีมีบรรทัด "(บาท)" หรือ "บาท" คั่นกลาง
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim().toLowerCase();
      final isAmountLabel = line == 'จำนวนเงิน' ||
          line == 'จํานวนเงิน' ||
          line.startsWith('จำนวนเงิน') ||
          line.startsWith('จํานวนเงิน') ||
          line.contains('จำนวนเงิน') ||
          line.contains('จํานวนเงิน') ||
          line.contains('ยอดเงิน') ||
          line.contains('ยอดโอน') ||
          line == 'amount' ||
          line.startsWith('amount');

      if (isAmountLabel) {
        for (int j = i + 1; j < lines.length && j <= i + 3; j++) {
          final nextLine = lines[j].trim();
          final lowerNext = nextLine.toLowerCase();
          if (lowerNext == '(บาท)' || lowerNext == 'บาท' || lowerNext == 'baht' || lowerNext == 'thb' || lowerNext == ':') {
            continue;
          }
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
    }

    // Pattern 3: สแกนหาตัวเลขทศนิยม 2 ตำแหน่งที่มีสัญลักษณ์ บาท / Baht / THB / ฿ อยู่ข้างๆ
    final regexCurrency = RegExp(
      r'(?:(?:฿|thb)\s*([0-9,]+\.[0-9]{2})|([0-9,]+\.[0-9]{2})\s*(?:บาท|baht|thb))',
      caseSensitive: false,
    );
    final currencyMatch = regexCurrency.firstMatch(fullText);
    if (currencyMatch != null) {
      final rawNum = currencyMatch.group(1) ?? currencyMatch.group(2);
      final clean = rawNum?.replaceAll(',', '');
      if (clean != null) {
        final val = double.tryParse(clean);
        if (val != null && val > 0) return val;
      }
    }

    // Pattern 4: ตัวเลขทศนิยม 2 ตำแหน่งโดดๆ ในบรรทัด (พบบ่อยใน K PLUS สลิปแบบกราฟิกธีม)
    for (final line in lines) {
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
        return DateTime(year, entry.value, day, hour, minute);
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
        return DateTime(year, month, day, hour, minute);
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
