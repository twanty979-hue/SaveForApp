import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Transactions Running Total Calculation Tests', () {
    test('calculates running cumulative total progressively step-by-step', () {
      final transactions = [
        {'amount': 60.0, 'date': '2026-09-01T00:22:00Z', 'type': 'expense'},
        {'amount': 50.0, 'date': '2026-09-01T12:40:00Z', 'type': 'expense'},
        {'amount': 390.0, 'date': '2026-09-02T11:16:00Z', 'type': 'expense'},
        {'amount': 100.0, 'date': '2026-09-02T12:32:00Z', 'type': 'expense'},
        {'amount': 10.0, 'date': '2026-09-02T14:48:00Z', 'type': 'expense'},
        {'amount': 40.0, 'date': '2026-09-02T15:00:00Z', 'type': 'expense'},
        {'amount': 200.0, 'date': '2026-09-03T12:29:00Z', 'type': 'expense'},
      ];

      final Map<String, double> monthlyExpenseRunningTotal = {};
      final List<double> accumulatedPerCard = [];

      for (var tx in transactions) {
        final amount = (tx['amount'] as num).toDouble();
        final timestamp = DateTime.parse(tx['date'] as String);
        final monthKey = '${timestamp.year}_${timestamp.month}';

        monthlyExpenseRunningTotal[monthKey] =
            (monthlyExpenseRunningTotal[monthKey] ?? 0.0) + amount;
        final totalAccumulated = monthlyExpenseRunningTotal[monthKey]!;
        accumulatedPerCard.add(totalAccumulated);
      }

      // Verify that running total strictly increases and is not equal on every card
      expect(accumulatedPerCard, [
        60.0,
        110.0,
        500.0,
        600.0,
        610.0,
        650.0,
        850.0,
      ]);
    });

    test('different months have independent running totals', () {
      final transactions = [
        {'amount': 100.0, 'date': '2026-08-31T10:00:00Z', 'type': 'expense'},
        {'amount': 50.0, 'date': '2026-09-01T10:00:00Z', 'type': 'expense'},
        {'amount': 70.0, 'date': '2026-09-02T10:00:00Z', 'type': 'expense'},
      ];

      final Map<String, double> monthlyExpenseRunningTotal = {};
      final List<double> accumulatedPerCard = [];

      for (var tx in transactions) {
        final amount = (tx['amount'] as num).toDouble();
        final timestamp = DateTime.parse(tx['date'] as String);
        final monthKey = '${timestamp.year}_${timestamp.month}';

        monthlyExpenseRunningTotal[monthKey] =
            (monthlyExpenseRunningTotal[monthKey] ?? 0.0) + amount;
        final totalAccumulated = monthlyExpenseRunningTotal[monthKey]!;
        accumulatedPerCard.add(totalAccumulated);
      }

      // August starts at 100, September resets and starts at 50, then 120
      expect(accumulatedPerCard, [
        100.0,
        50.0,
        120.0,
      ]);
    });
    test('transfer transactions are completely excluded from expense and income running totals', () {
      final transactions = [
        {'amount': 100.0, 'date': '2026-09-01T10:00:00Z', 'type': 'expense'},
        {'amount': 5000.0, 'date': '2026-09-01T11:00:00Z', 'type': 'transfer'}, // ย้ายเงิน ไม่ควรถูกนับ
        {'amount': 50.0, 'date': '2026-09-01T12:00:00Z', 'type': 'expense'},
      ];

      final Map<String, double> monthlyExpenseRunningTotal = {};
      final List<double> expenseAccumulated = [];

      for (var tx in transactions) {
        final amount = (tx['amount'] as num).toDouble();
        final timestamp = DateTime.parse(tx['date'] as String);
        final monthKey = '${timestamp.year}_${timestamp.month}';
        final type = tx['type'] as String;

        if (type == 'expense') {
          monthlyExpenseRunningTotal[monthKey] =
              (monthlyExpenseRunningTotal[monthKey] ?? 0.0) + amount;
          expenseAccumulated.add(monthlyExpenseRunningTotal[monthKey]!);
        } else if (type == 'transfer') {
          // Transfer is excluded from expense running total
          expenseAccumulated.add(monthlyExpenseRunningTotal[monthKey] ?? 0.0);
        }
      }

      expect(expenseAccumulated, [
        100.0,
        100.0, // 5000.0 transfer did not increase total
        150.0,
      ]);
    });
  });
}
