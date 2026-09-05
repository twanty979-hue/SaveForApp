import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/services/slip_parser_service.dart';

void main() {
  group('SlipParserService Tests', () {
    test('Correctly parses SCB slip', () {
      final lines = [
        'โอนเงินสำเร็จ',
        'ธนาคารไทยพาณิชย์',
        '05 ก.ย. 2569 - 14:35',
        'รหัสอ้างอิง: 20260905SCB123456',
        'จาก นายต้นกล้า ออมเงิน',
        'ไปยัง ร้านกาแฟ อร่อยดี',
        'จำนวนเงิน',
        '120.00 บาท',
      ];
      final fullText = lines.join('\n');

      final slip = SlipParserService.instance.parse(
        id: 'test_scb_1',
        lines: lines,
        fullText: fullText,
      );

      expect(slip, isNotNull);
      expect(slip!.bank, equals(BankType.scb));
      expect(slip.amount, equals(120.0));
      expect(slip.recipient, contains('ร้านกาแฟ อร่อยดี'));
      expect(slip.referenceNo, equals('20260905SCB123456'));
      expect(slip.date.year, equals(2026));
      expect(slip.date.month, equals(9));
      expect(slip.date.day, equals(5));
    });

    test('Correctly parses KBank slip', () {
      final lines = [
        'K PLUS',
        'โอนเงินสำเร็จ',
        'ธนาคารกสิกรไทย',
        'วันที่ 01 ส.ค. 69 09:15 น.',
        'เลขที่รายการ: KB20260801999',
        'จาก นาย เอ',
        'ไปยัง น.ส. บี ใจดี',
        'จำนวนเงิน: 1,550.00 บาท',
      ];
      final fullText = lines.join('\n');

      final slip = SlipParserService.instance.parse(
        id: 'test_kbank_1',
        lines: lines,
        fullText: fullText,
      );

      expect(slip, isNotNull);
      expect(slip!.bank, equals(BankType.kbank));
      expect(slip.amount, equals(1550.0));
      expect(slip.recipient, contains('น.ส. บี ใจดี'));
      expect(slip.referenceNo, equals('KB20260801999'));
    });

    test('Correctly parses Krungsri slip', () {
      final lines = [
        'KMA krungsri',
        'โอนเงินสำเร็จ',
        'ธนาคารกรุงศรีอยุธยา',
        '15 ก.ค. 2569 18:20',
        'รหัสอ้างอิง: BAY88776655',
        'โอนไปยัง นายสมศักดิ์ ขยันยิ่ง',
        'จำนวนเงิน 450.00',
      ];
      final fullText = lines.join('\n');

      final slip = SlipParserService.instance.parse(
        id: 'test_krungsri_1',
        lines: lines,
        fullText: fullText,
      );

      expect(slip, isNotNull);
      expect(slip!.bank, equals(BankType.krungsri));
      expect(slip.amount, equals(450.0));
      expect(slip.recipient, contains('นายสมศักดิ์ ขยันยิ่ง'));
      expect(slip.referenceNo, equals('BAY88776655'));
    });

    test('Rejects non-slip text', () {
      final lines = [
        'สวัสดีครับ ยินดีต้อนรับ',
        'วันนี้อากาศดีมาก',
      ];
      final fullText = lines.join('\n');

      final slip = SlipParserService.instance.parse(
        id: 'test_invalid',
        lines: lines,
        fullText: fullText,
      );

      expect(slip, isNull);
    });
  });
}
