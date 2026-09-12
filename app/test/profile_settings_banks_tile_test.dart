import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app/core/models/bank_rule_model.dart';
import 'package:app/core/services/bank_rules_service.dart';
import 'package:app/core/settings/app_settings.dart';
import 'package:app/features/profile/presentation/profile_settings_screen.dart';
import 'package:app/features/profile/presentation/supported_banks_screen.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    AppSettings.enabledAutoScanBanks.value = {
      'kbank',
      'scb',
      'krungsri',
      'truemoney',
      'ktb',
    };
    BankRulesService.rulesNotifier.value = BankRuleConfig.defaultRules;
  });

  testWidgets('ProfileSettingsScreen renders ธนาคารที่อ่านสลิป tile and navigates to SupportedBanksScreen', (tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('th'),
        supportedLocales: [Locale('th'), Locale('en')],
        localizationsDelegates: [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: ProfileSettingsScreen(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Verify tile exists on profile settings screen with correct 5/5 count
    expect(find.text('ธนาคารที่อ่านสลิป'), findsOneWidget);
    expect(find.text('เลือกเปิด-ปิดธนาคารที่ต้องการให้อ่านสลิป (5/5 ธนาคาร)'), findsOneWidget);
    expect(find.text('5/5'), findsOneWidget);

    // Tap tile to navigate
    await tester.tap(find.text('ธนาคารที่อ่านสลิป'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Verify navigated to SupportedBanksScreen
    expect(find.byType(SupportedBanksScreen), findsOneWidget);
  });

  testWidgets('ProfileSettingsScreen opens Language Selection sheet and changes locale with flag image icons', (tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    AppSettings.locale.value = const Locale('th');

    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('th'),
        supportedLocales: [Locale('th'), Locale('en')],
        localizationsDelegates: [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: ProfileSettingsScreen(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Find and tap the language settings tile
    expect(find.text('ภาษา'), findsOneWidget);
    await tester.tap(find.text('ภาษา'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Bottom sheet is displayed with flags and titles
    expect(find.text('ภาษาไทย'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
    expect(find.text('Thai'), findsOneWidget);
    expect(find.text('อังกฤษ'), findsOneWidget);

    // Verify there are Image widgets for flags
    expect(find.byType(Image), findsAtLeastNWidgets(2));

    // Tap English option
    await tester.tap(find.text('English'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify locale changed to English
    expect(AppSettings.locale.value.languageCode, 'en');
  });
}
