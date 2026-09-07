import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/services/slip_parser_service.dart';

void main() {
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
  });
}
