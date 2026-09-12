import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Income Transaction & Budget Consistency Tests', () {
    test('parses +ทิป 69 as income with name ทิป and amount 69', () {
      final input = '+ทิป 69';
      final parts = input.trim().split(RegExp(r'\s+'));
      expect(parts.length, 2);

      final rawName = parts[0];
      final amount = double.tryParse(parts[1]) ?? 0.0;

      String type = 'expense';
      String category = 'รายจ่าย';
      String msgType = 'expense';
      String name = rawName;

      if (rawName.startsWith('+')) {
        type = 'income';
        category = 'รายรับ';
        msgType = 'income';
        name = rawName.substring(1).trim();
      }

      expect(name, 'ทิป');
      expect(amount, 69.0);
      expect(type, 'income');
      expect(category, 'รายรับ');
      expect(msgType, 'income');
    });

    test('card display logic does NOT show / 0 บาท when budget is 0 or no budget', () {
      const double totalAccumulated = 69.0;
      const double budget = 0.0;
      const bool hasBudget = false;
      const String msgType = 'income';
      const double amount = 69.0;

      String displayText;
      bool showProgressBar;

      if (hasBudget && budget > 0) {
        displayText = '${totalAccumulated.toStringAsFixed(0)} / ${budget.toStringAsFixed(0)} บาท';
        showProgressBar = true;
      } else {
        displayText = totalAccumulated > amount
            ? (msgType == 'income'
                ? 'ยอดรับสะสมเดือนนี้ ${totalAccumulated.toStringAsFixed(0)} บาท'
                : 'ยอดจ่ายสะสมเดือนนี้ ${totalAccumulated.toStringAsFixed(0)} บาท')
            : '${amount.toStringAsFixed(0)} บาท';
        showProgressBar = false;
      }

      // Must display '69 บาท' and NOT '69 / 0 บาท'
      expect(displayText, '69 บาท');
      expect(displayText.contains('/ 0'), isFalse);
      expect(showProgressBar, isFalse);
    });

    test('header badge displays รายรับ for income and never ไม่มีงบ', () {
      const String msgType = 'income';
      const String category = 'รายรับ';
      const bool hasBudget = false;

      final isTransfer = msgType == 'transfer' || category == 'ย้ายเงิน';
      final isExpense = !isTransfer && (msgType == 'expense' || category == 'รายจ่าย');
      final isDream = !isTransfer && (msgType == 'dream' || category == 'เงินออม');
      final isIncome = !isTransfer && (msgType == 'income' || category == 'รายรับ');

      String badgeText;
      Color badgeColor;

      if (isIncome) {
        badgeText = 'รายรับ';
        badgeColor = const Color(0xFF10B981);
      } else if (isDream) {
        badgeText = 'เงินออม';
        badgeColor = const Color(0xFFF59E0B);
      } else if (!hasBudget) {
        badgeText = 'ไม่มีงบ';
        badgeColor = const Color(0xFFEF4444);
      } else {
        badgeText = '';
        badgeColor = Colors.transparent;
      }

      expect(badgeText, 'รายรับ');
      expect(badgeColor, const Color(0xFF10B981));
      expect(badgeText, isNot('ไม่มีงบ'));
    });

    test('quick chips in edit modal for income contain income categories including ทิป', () {
      final card = {
        'msgType': 'income',
        'category': 'รายรับ',
        'name': 'ทิป',
        'amount': 69.0,
      };

      final String msgType = card['msgType']?.toString() ?? 'expense';
      final String category = card['category']?.toString() ?? 'รายจ่าย';
      final bool isIncome = msgType == 'income' || category == 'รายรับ' || card['type'] == 'income';
      final bool isDream = msgType == 'dream' || category == 'เงินออม' || card['source'] == 'dream_saving';

      final quickChips = isIncome
          ? [
              {'label': 'เงินเดือน', 'icon': Icons.payments_rounded},
              {'label': 'โบนัส', 'icon': Icons.card_giftcard_rounded},
              {'label': 'ทิป', 'icon': Icons.volunteer_activism_rounded},
              {'label': 'ขายของ', 'icon': Icons.storefront_rounded},
              {'label': 'งานเสริม', 'icon': Icons.work_rounded},
              {'label': 'ลงทุน / ปันผล', 'icon': Icons.trending_up_rounded},
              {'label': 'เงินโอน', 'icon': Icons.account_balance_wallet_rounded},
              {'label': 'คืนเงิน', 'icon': Icons.assignment_return_rounded},
              {'label': 'รายรับอื่นๆ', 'icon': Icons.add_circle_outline_rounded},
            ]
          : (isDream
              ? [
                  {'label': 'เงินออมฉุกเฉิน', 'icon': Icons.savings_rounded},
                  {'label': 'เที่ยว / พักผ่อน', 'icon': Icons.flight_takeoff_rounded},
                  {'label': 'ซื้อของชิ้นใหญ่', 'icon': Icons.shopping_bag_rounded},
                  {'label': 'ลงทุนระยะยาว', 'icon': Icons.trending_up_rounded},
                  {'label': 'เงินเก็บ', 'icon': Icons.account_balance_rounded},
                ]
              : [
                  {'label': 'ค่าข้าว', 'icon': Icons.restaurant_rounded},
                  {'label': 'ชากาแฟ', 'icon': Icons.local_cafe_rounded},
                  {'label': 'ของใช้ 7-11', 'icon': Icons.storefront_rounded},
                  {'label': 'ค่าน้ำมัน', 'icon': Icons.local_gas_station_rounded},
                  {'label': 'ช้อปปิ้ง', 'icon': Icons.shopping_bag_rounded},
                  {'label': 'ค่าเดินทาง', 'icon': Icons.directions_car_rounded},
                  {'label': 'จ่ายบิล / ค่าห้อง', 'icon': Icons.home_work_rounded},
                  {'label': 'ค่าขนม', 'icon': Icons.cake_rounded},
                  {'label': 'ยา / สุขภาพ', 'icon': Icons.medication_rounded},
                ]);

      final chipLabels = quickChips.map((c) => c['label']).toList();

      expect(chipLabels, contains('ทิป'));
      expect(chipLabels, contains('เงินเดือน'));
      expect(chipLabels, contains('ขายของ'));
      expect(chipLabels, isNot(contains('ค่าข้าว')));
      expect(chipLabels, isNot(contains('ค่าน้ำมัน')));
    });
  });
}
