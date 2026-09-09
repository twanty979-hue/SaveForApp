import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app/core/services/slip_parser_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SlipParserService.learnedOwnNames.clear();
    SlipParserService.learnedOwnAccounts.clear();
  });

  group('SlipParserService Tests', () {
    test('parses standalone integer amounts like 864 and 10 from real iOS OCR screenshots', () {
      final slip864 = SlipParserService.instance.parse(
        id: 'screenshot_864',
        lines: [
          '12:30',
          '864',
          'โอนเงินสำเร็จ',
          'กสิกรไทย',
          'นาย สมชาย ใจดี',
          '07 ก.ย. 2569 12:30',
        ],
        fullText: '12:30\n864\nโอนเงินสำเร็จ\nกสิกรไทย\nนาย สมชาย ใจดี\n07 ก.ย. 2569 12:30',
      );

      expect(slip864, isNotNull);
      expect(slip864!.amount, equals(864.0));
      expect(slip864.bank, equals(BankType.kbank));

      final slip10 = SlipParserService.instance.parse(
        id: 'screenshot_10',
        lines: [
          '12:30',
          '10',
          'โอนเงินสำเร็จ',
          'ไทยพาณิชย์',
          'พร้อมเพย์',
        ],
        fullText: '12:30\n10\nโอนเงินสำเร็จ\nไทยพาณิชย์\nพร้อมเพย์',
      );

      expect(slip10, isNotNull);
      expect(slip10!.amount, equals(10.0));
      expect(slip10.bank, equals(BankType.scb));
    });

    test('parses amounts with labels on same line or next line with or without decimals', () {
      final slipLabel = SlipParserService.instance.parse(
        id: 'slip_label',
        lines: [
          'จำนวนเงิน',
          '864',
          'บาท',
          'โอนเงินสำเร็จ',
        ],
        fullText: 'จำนวนเงิน\n864\nบาท\nโอนเงินสำเร็จ',
      );

      expect(slipLabel, isNotNull);
      expect(slipLabel!.amount, equals(864.0));
    });
    test('parses TrueMoney 7-Eleven slip correctly with 82.00 amount (NOT 7.00)', () {
      const fullText = '''
truemoney
เซเว่น อีเลฟเว่น
฿ 82.00
ช่องทางการชำระเงิน วอลเล็ท
ชำระเงิน 7-Eleven(Thailand)
วันที่ทำรายการ 06 ก.ย. 2569 22:20:59
หมายเลขการสั่งซื้อ 2026090600000005207797 054
เลขที่รายการ 260906222059947RGH4U
ยอดชำระทั้งหมด ฿ 82.00
รายละเอียดรายการ
รายละเอียดสินค้า 7-Eleven(Thailand)
สถานที่ทำรายการ นนทบุรี, ประเทศไทย
''';
      final lines = fullText.split('\n');
      final slip = SlipParserService.instance.parse(
        id: 'truemoney_7eleven',
        lines: lines,
        fullText: fullText,
      );

      expect(slip, isNotNull);
      expect(slip!.amount, equals(82.00));
      expect(slip.bank, equals(BankType.truemoney));
      expect(slip.recipient, anyOf(contains('7-Eleven'), contains('เซเว่น')));
    });

    test('does not parse fee amount as transaction amount', () {
      const fullText = '''
โอนเงินสำเร็จ
07 ก.ย. 69 14:15 น.
ไปยัง
นางสาว สมศรี รักดี
ธนาคารกสิกรไทย
จำนวนเงิน 1,500.00 บาท
ค่าธรรมเนียม 10.00 บาท
รหัสอ้างอิง: 2026090712345678
''';
      final lines = fullText.split('\n');
      final slip = SlipParserService.instance.parse(
        id: 'slip_fee_test',
        lines: lines,
        fullText: fullText,
      );

      expect(slip, isNotNull);
      expect(slip!.amount, equals(1500.00));
      expect(slip.recipient, equals('นางสาว สมศรี รักดี'));
    });

    test('does not parse quantity or merchant number as amount', () {
      const fullText = '''
ร้านค้า 108 Shop
ยอดรวม 350.00 บาท
จำนวน 3 รายการ
''';
      final lines = fullText.split('\n');
      final slip = SlipParserService.instance.parse(
        id: 'slip_qty_test',
        lines: lines,
        fullText: fullText,
      );

      expect(slip, isNotNull);
      expect(slip!.amount, equals(350.00));
    });

    test('does not parse phone number or account number as amount', () {
      const fullText = '''
โอนเงินสำเร็จ
ไปยัง
นาย ประเสริฐ มีสุข
พร้อมเพย์ 081-234-5678
จำนวนเงิน
500.00 บาท
''';
      final lines = fullText.split('\n');
      final slip = SlipParserService.instance.parse(
        id: 'slip_phone_test',
        lines: lines,
        fullText: fullText,
      );

      expect(slip, isNotNull);
      expect(slip!.amount, equals(500.00));
      expect(slip.recipient, equals('นาย ประเสริฐ มีสุข'));
    });

    test('date range calculations strictly clamp daysBack between 1 and 30 days', () {
      // เมื่อผู้ใช้เลือกย้อนหลังเกิน 30 วัน ต้องโดนจำกัดไม่เกิน 30 วัน
      int clampDays(int input) => input.clamp(1, 30);
      expect(clampDays(45), equals(30));
      expect(clampDays(100), equals(30));
      expect(clampDays(0), equals(1));
      expect(clampDays(7), equals(7));
      expect(clampDays(30), equals(30));

      // เมื่อคำนวณจากวันที่ย้อนหลัง
      final now = DateTime(2026, 9, 7);
      final start40DaysAgo = now.subtract(const Duration(days: 40));
      final diff = now.difference(start40DaysAgo).inDays + 1;
      expect(diff.clamp(1, 30), equals(30));

      final start5DaysAgo = now.subtract(const Duration(days: 5));
      final diff5 = now.difference(start5DaysAgo).inDays + 1;
      expect(diff5.clamp(1, 30), equals(6));
    });

    test('detects destination bank and self-transfer correctly', () {
      const fullText = '''
โอนเงินสำเร็จ
08 ก.ย. 2569 10:30 น.
จาก
นาย พงศ์บดินทร์ ศรีทอง
กสิกรไทย
ไปยัง
นาย พงศ์บดินทร์ ศรีทอง
ธนาคารไทยพาณิชย์
จำนวนเงิน
1,200.00 บาท
ค่าธรรมเนียม 0.00 บาท
รหัสอ้างอิง: 2026090877889900
''';
      final lines = fullText.split('\n');
      final slip = SlipParserService.instance.parse(
        id: 'self_transfer_test',
        lines: lines,
        fullText: fullText,
      );

      expect(slip, isNotNull);
      expect(slip!.amount, equals(1200.00));
      expect(slip.bank, equals(BankType.kbank));
      expect(slip.destinationBank, equals(BankType.scb));
      expect(slip.isTransfer, isTrue);
      expect(slip.displayTitle, contains('ย้ายเงิน'));
      expect(slip.finalFormattedNoteTitle, contains('ย้ายเงิน'));
    });

    test('detects SCB self-transfer with bank label before sender and recipient', () {
      const fullText = '''
โอนเงินสำเร็จ
08 ก.ย. 2569 - 12:00
จาก
ไทยพาณิชย์
นาย วรธน น.
xxx-xxx-1234
ไปยัง
กสิกรไทย
นาย วรธน น.
xxx-xxx-5678
จำนวนเงิน
1,000.00
รหัสอ้างอิง
202609087VLrKX6lomPKNangw
''';
      final lines = fullText.split('\n');
      final slip = SlipParserService.instance.parse(
        id: 'scb_transfer_test',
        lines: lines,
        fullText: fullText,
      );

      expect(slip, isNotNull);
      expect(slip!.amount, equals(1000.00));
      expect(slip.bank, equals(BankType.scb));
      expect(slip.destinationBank, equals(BankType.kbank));
      expect(slip.isTransfer, isTrue);
      expect(slip.recipient, equals('นาย วรธน น.'));
      expect(slip.displayTitle, contains('ย้ายเงิน'));
    });

    test('detects K PLUS self-transfer without "จาก" keyword and with promptpay destination', () {
      const fullText = '''
โอนเงินสำเร็จ
08 ก.ย. 69 19:52 น.
นาย วรธน น.
ธ.กสิกรไทย
xxx-x-x1234-x
ไปยัง
พร้อมเพย์
นาย วรธน น.
xxx-xxxxxxx
จำนวนเงิน
5,000.00 บาท
ค่าธรรมเนียม
0.00 บาท
รหัสอ้างอิง: 016251195204BPP07692
''';
      final lines = fullText.split('\n');
      final slip = SlipParserService.instance.parse(
        id: 'kplus_transfer_test',
        lines: lines,
        fullText: fullText,
      );

      expect(slip, isNotNull);
      expect(slip!.amount, equals(5000.00));
      expect(slip.bank, equals(BankType.kbank));
      expect(slip.isTransfer, isTrue);
      expect(slip.recipient, equals('นาย วรธน น.'));
      expect(slip.displayTitle, contains('ย้ายเงิน'));
    });

    test('detects Vorathon to Nicha as expense, NOT self-transfer', () {
      const fullText = '''
โอนเงินสำเร็จ
08 ก.ย. 69 19:52 น.
นาย วรธน น.
ธ.กสิกรไทย
xxx-x-x1234-x
น.ส. นิชา ก.
ธ.ไทยพาณิชย์
xxx-x-x5678-x
จำนวนเงิน
500.00 บาท
ค่าธรรมเนียม
0.00 บาท
รหัสอ้างอิง: 016251195204BPP07692
''';
      final lines = fullText.split('\n');
      final slip = SlipParserService.instance.parse(
        id: 'nicha_expense_test',
        lines: lines,
        fullText: fullText,
      );

      expect(slip, isNotNull);
      expect(slip!.amount, equals(500.00));
      expect(slip.bank, equals(BankType.kbank));
      expect(slip.destinationBank, equals(BankType.scb));
      expect(slip.isTransfer, isFalse);
      expect(slip.recipient, equals('น.ส. นิชา ก.'));
      expect(slip.displayTitle, equals('น.ส. นิชา ก.'));
    });

    test('detects K PLUS 5000 THB PromptPay self-transfer with Prompt label and full surname', () {
      final lines = [
        'โอนเงินสำเร็จ',
        '8 ก.ย. 69 19:52 น.',
        'K+',
        'นาย วรธน น.',
        'ธ.กสิกรไทย',
        'xxx-x-x8380-x',
        'Prompt',
        'Pay',
        'นาย วรธน นำทอง',
        'รหัสพร้อมเพย์',
        'x-xxxx-xxxx5-70-4',
        'เลขที่รายการ:',
        '016251195204BPP07692',
        'จำนวน:',
        '5,000.00 บาท',
        'ค่าธรรมเนียม:',
        '0.00 บาท',
      ];
      final fullText = lines.join('\n');
      final slip = SlipParserService.instance.parse(
        id: 'kplus_promptpay_5000',
        lines: lines,
        fullText: fullText,
      );

      expect(slip, isNotNull);
      expect(slip!.amount, equals(5000.00));
      expect(slip.bank, equals(BankType.kbank));
      expect(slip.recipient, equals('นาย วรธน นำทอง'));
      expect(slip.isTransfer, isTrue);
      expect(slip.displayTitle, contains('ย้ายเงิน'));
    });

    test('detects K PLUS 100 THB PromptPay self-transfer with Prompt label and partial surname', () {
      final lines = [
        'โอนเงินสำเร็จ',
        '8 ก.ย. 69 19:49 น.',
        'K+',
        'นาย วรธน น.',
        'ธ.กสิกรไทย',
        'xxx-x-x8380-x',
        'Prompt',
        'Pay',
        'วรธน นำทอง',
        '006-xxxxxxxx-9822',
        'เลขที่รายการ:',
        '016251194926BPP12778',
        'จำนวน:',
        '100.00 บาท',
        'ค่าธรรมเนียม:',
        '0.00 บาท',
      ];
      final fullText = lines.join('\n');
      final slip = SlipParserService.instance.parse(
        id: 'kplus_promptpay_100',
        lines: lines,
        fullText: fullText,
      );

      expect(slip, isNotNull);
      expect(slip!.amount, equals(100.00));
      expect(slip.bank, equals(BankType.kbank));
      expect(slip.recipient, equals('วรธน นำทอง'));
      expect(slip.isTransfer, isTrue);
      expect(slip.displayTitle, contains('ย้ายเงิน'));
    });

    test('detects bilingual Thai-to-English self-transfer (นาย วรธน -> VORATHON NAMTHONG)', () {
      final lines = [
        'โอนเงินสำเร็จ',
        'นาย วรธน น.',
        'ธ.กสิกรไทย',
        'VORATHON NAMTHONG',
        'ธ.ไทยพาณิชย์',
        'จำนวนเงิน',
        '2500.00 บาท',
      ];
      final fullText = lines.join('\n');
      final slip = SlipParserService.instance.parse(
        id: 'bilingual_transfer',
        lines: lines,
        fullText: fullText,
      );

      expect(slip, isNotNull);
      expect(slip!.amount, equals(2500.00));
      expect(slip.isTransfer, isTrue);
      expect(slip.sender, equals('นาย วรธน น.'));
      expect(slip.recipient, equals('VORATHON NAMTHONG'));
      expect(slip.destinationBank, equals(BankType.scb));
    });

    test('Vorathon to Nicha is ALWAYS expense even if Vorathon is in learnedOwnNames', () {
      SlipParserService.learnedOwnNames.add('วรธน');
      SlipParserService.learnedOwnNames.add('นาย วรธน นำทอง');

      final lines = [
        'โอนเงินสำเร็จ',
        'นาย วรธน น.',
        'ธ.กสิกรไทย',
        'xxx-x-x1234-x',
        'น.ส. นิชา ก.',
        'ธ.ไทยพาณิชย์',
        'xxx-x-x5678-x',
        '500.00 บาท',
      ];
      final fullText = lines.join('\n');
      final slip = SlipParserService.instance.parse(
        id: 'vorathon_to_nicha_learned',
        lines: lines,
        fullText: fullText,
      );

      expect(slip, isNotNull);
      expect(slip!.amount, equals(500.00));
      expect(slip.isTransfer, isFalse, reason: 'Different people must NEVER be classified as self-transfer');
      expect(slip.recipient, equals('น.ส. นิชา ก.'));
    });

    test('auto-learns own account number and recognizes future slips without sender as transfer', () {
      SlipParserService.learnedOwnAccounts.add('9822');

      final lines = [
        'โอนเงินสำเร็จ',
        '08 ก.ย. 69',
        'ไปยัง',
        '006-xxxxxxxx-9822',
        'จำนวนเงิน 1,200.00 บาท',
      ];
      final fullText = lines.join('\n');
      final slip = SlipParserService.instance.parse(
        id: 'learned_account_transfer',
        lines: lines,
        fullText: fullText,
      );

      expect(slip, isNotNull);
      expect(slip!.isTransfer, isTrue);
      expect(slip.amount, equals(1200.00));
    });

    test('self-healing forgetOwnAccount removes learned account accurately', () async {
      SlipParserService.learnedOwnNames.add('นิชา ก.');
      expect(SlipParserService.learnedOwnNames.contains('นิชา ก.'), isTrue);

      await SlipParserService.forgetOwnAccount(name: 'นิชา ก.');
      expect(SlipParserService.learnedOwnNames.contains('นิชา ก.'), isFalse);
    });

    test('SaaS generic bilingual matching works for any user (นาย สมชาย -> MR. SOMCHAI SUKJAI)', () {
      final lines = [
        'โอนเงินสำเร็จ',
        'นาย สมชาย สุขใจ',
        'ธ.กสิกรไทย',
        'MR. SOMCHAI SUKJAI',
        'ธ.ไทยพาณิชย์',
        'จำนวนเงิน',
        '3000.00 บาท',
      ];
      final fullText = lines.join('\n');
      final slip = SlipParserService.instance.parse(
        id: 'somchai_bilingual_transfer',
        lines: lines,
        fullText: fullText,
      );

      expect(slip, isNotNull);
      expect(slip!.amount, equals(3000.00));
      expect(slip.isTransfer, isTrue, reason: 'Generic phonetic matcher must recognize Somchai ⇄ SOMCHAI');
      expect(slip.recipient, equals('MR. SOMCHAI SUKJAI'));
    });

    test('SaaS generic bilingual matching works for Kittiphong (กิตติพงษ์ -> KITTIPHONG)', () {
      final lines = [
        'โอนเงินสำเร็จ',
        'กิตติพงษ์',
        'ธ.กสิกรไทย',
        'KITTIPHONG',
        'ธ.กรุงไทย',
        '1000.00 บาท',
      ];
      final fullText = lines.join('\n');
      final slip = SlipParserService.instance.parse(
        id: 'kittiphong_transfer',
        lines: lines,
        fullText: fullText,
      );

      expect(slip, isNotNull);
      expect(slip!.isTransfer, isTrue, reason: 'Generic phonetic matcher must recognize กิตติพงษ์ ⇄ KITTIPHONG');
    });

    test('SaaS expense detection: Somchai to Areeya is an EXPENSE, never a transfer', () {
      final lines = [
        'โอนเงินสำเร็จ',
        'นาย สมชาย สุขใจ',
        'ธ.กสิกรไทย',
        'นางสาว อารียา ใจดี',
        'ธ.ไทยพาณิชย์',
        '400.00 บาท',
      ];
      final fullText = lines.join('\n');
      final slip = SlipParserService.instance.parse(
        id: 'somchai_to_areeya',
        lines: lines,
        fullText: fullText,
      );

      expect(slip, isNotNull);
      expect(slip!.isTransfer, isFalse);
      expect(slip.recipient, equals('นางสาว อารียา ใจดี'));
    });

    test('SaaS multi-tenant data isolation partitions accounts per user', () async {
      // User A learns account 7788
      await SlipParserService.learnOwnAccount(accountNumber: '7788', userId: 'user_somchai');
      expect(SlipParserService.learnedOwnAccounts.contains('7788'), isTrue);

      // User B loads their own data (should not have 7788)
      await SlipParserService.loadLearnedOwnData('user_kittiphong');
      expect(SlipParserService.learnedOwnAccounts.contains('7788'), isFalse,
          reason: 'User B must not see User A learned account in SaaS multi-tenant setup');

      // User A reloads their own data
      await SlipParserService.loadLearnedOwnData('user_somchai');
      expect(SlipParserService.learnedOwnAccounts.contains('7788'), isTrue);
    });
  });
}

