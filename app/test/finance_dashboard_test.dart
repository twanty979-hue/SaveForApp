import 'package:flutter/material.dart' as material;
import 'package:flutter_test/flutter_test.dart';
import 'package:app/features/dashboard/presentation/finance_dashboard_screen.dart';

void main() {
  test('FinanceDashboardScreen.isTransferTransaction returns boolean without StackOverflow', () {
    expect(FinanceDashboardScreen.isTransferTransaction({}), isFalse);
    expect(FinanceDashboardScreen.isTransferTransaction({'type': 'transfer'}), isTrue);
    expect(FinanceDashboardScreen.isTransferTransaction({'note': '[ย้ายเงิน] บัญชีหลัก'}), isTrue);
  });

  testWidgets('pumps FinanceDashboardScreen widget successfully', (tester) async {
    await tester.pumpWidget(
      const material.MaterialApp(
        home: FinanceDashboardScreen(),
      ),
    );
    expect(find.byType(FinanceDashboardScreen), findsOneWidget);
    await tester.pump();
  });
}
