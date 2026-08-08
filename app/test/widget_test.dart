import 'package:flutter/material.dart' as material;
import 'package:flutter_test/flutter_test.dart';

import 'package:app/core/localization/localized_text.dart' as localized;
import 'package:app/core/settings/app_settings.dart';

void main() {
  testWidgets('shared text follows the selected app language', (tester) async {
    AppSettings.locale.value = const material.Locale('en');

    await tester.pumpWidget(
      const material.MaterialApp(
        home: material.Scaffold(body: localized.Text('ภาษา')),
      ),
    );

    expect(find.text('Language'), findsOneWidget);
    expect(find.text('ภาษา'), findsNothing);
  });

  testWidgets('user-entered text is not modified', (tester) async {
    AppSettings.locale.value = const material.Locale('en');

    await tester.pumpWidget(
      const material.MaterialApp(
        home: material.Scaffold(body: localized.Text('ค่าห้องของน้องเมย์')),
      ),
    );

    expect(find.text('ค่าห้องของน้องเมย์'), findsOneWidget);
  });
}
