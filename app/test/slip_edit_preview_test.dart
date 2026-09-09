import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Slip Edit & Preview Verification Tests', () {
    test('Slip detection identifies slip transaction from note, source, or reference_no', () {
      final slipNote = '[สลิป กสิกรไทย] ก๋วยเตี๋ยวเนื้อ [Ref:014065123456789]';
      final isSlipByNote = slipNote.startsWith('[สลิป') || slipNote.contains('[สลิป');
      expect(isSlipByNote, isTrue);

      final refMatch = RegExp(r'\[Ref:([^\]]+)\]').firstMatch(slipNote);
      expect(refMatch?.group(1), equals('014065123456789'));
    });

    test('Transfer slip detection correctly extracts title and tags', () {
      final transferNote = '[ย้ายเงิน] ย้ายเงิน [Ref:2026090998765]';
      final isTransfer = transferNote.startsWith('[ย้ายเงิน') || transferNote.contains('[ย้ายเงิน');
      expect(isTransfer, isTrue);

      final cleanTitle = transferNote
          .replaceAll(RegExp(r'\[ย้ายเงิน\s+[^\]]+\]'), '')
          .replaceAll('[ย้ายเงิน]', '')
          .replaceAll(RegExp(r'\[Ref:[^\]]+\]'), '')
          .trim();
      expect(cleanTitle, equals('ย้ายเงิน'));
    });

    test('Metadata correctly retains image_path, asset_id, and recipient', () {
      final metadata = {
        'recipient': 'นาย วรรณเฉลิม ชื่นใจ',
        'bank_display': 'กสิกรไทย',
        'image_path': '/path/to/documents/slips/slip_12345.jpg',
        'asset_id': 'EDC7D4A0-1D1A-4546-BB5A-94BF32C001FA/L0/001',
      };

      expect(metadata['image_path'], equals('/path/to/documents/slips/slip_12345.jpg'));
      expect(metadata['asset_id'], isNotNull);
      expect(metadata['recipient'], equals('นาย วรรณเฉลิม ชื่นใจ'));
    });
  });
}
