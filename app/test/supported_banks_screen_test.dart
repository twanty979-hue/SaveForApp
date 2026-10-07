import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app/core/models/bank_rule_model.dart';
import 'package:app/core/services/bank_rules_service.dart';
import 'package:app/core/settings/app_settings.dart';
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
      'ttb',
      'bbl',
      'gsb',
      'kkp',
      'baac',
      'uob',
      'cimb',
      'lhb',
      'tisco',
      'thaicredit',
      'shopeepay',
    };
    BankRulesService.rulesNotifier.value = BankRuleConfig.defaultRules;
  });

  Widget buildTestWidget() {
    return const MaterialApp(
      locale: Locale('th'),
      supportedLocales: [Locale('th'), Locale('en')],
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: SupportedBanksScreen(),
    );
  }

  testWidgets('SupportedBanksScreen renders clean SaaS auto-scan banks with logos, without schema leaks or keyword chips', (tester) async {
    tester.view.physicalSize = const Size(800, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(buildTestWidget());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Verify Read-Only / Internal Schema Notice is NOT shown
    expect(find.text('ซิงค์รายชื่อธนาคารจากระบบ Cloud'), findsNothing);
    expect(find.text('แอปอ่านอย่างเดียวเพื่อความปลอดภัย จัดการเพิ่มธนาคารและตั้งชื่ออัลบั้มได้ผ่านเว็บแอดมินครับ'), findsNothing);

    // Verify Cloud Sync button is hidden
    expect(find.byIcon(Icons.cloud_sync_rounded), findsNothing);

    // Verify Internal Keyword chips are hidden
    expect(find.text('k plus'), findsNothing);
    expect(find.text('kplus'), findsNothing);
    expect(find.text('k-plus'), findsNothing);
    expect(find.text('kasikorn'), findsNothing);

    // Verify Section 2 (Other Banks) is hidden
    expect(find.text('ธนาคารอื่นๆ (รองรับเมื่อเลือกรูปเอง)'), findsNothing);

    // Verify all 16 Banks
    expect(find.text('กสิกรไทย'), findsOneWidget);
    expect(find.text('ไทยพาณิชย์'), findsOneWidget);
    expect(find.text('กรุงศรีอยุธยา'), findsOneWidget);
    expect(find.text('ทรูมันนี่'), findsOneWidget);
    expect(find.text('กรุงไทย'), findsOneWidget);
    expect(find.text('ทีเอ็มบีธนชาต'), findsOneWidget);
    expect(find.text('กรุงเทพ'), findsOneWidget);
    expect(find.text('ออมสิน'), findsOneWidget);
    expect(find.text('เกียรตินาคินภัทร'), findsOneWidget);
    expect(find.text('ธ.ก.ส.'), findsOneWidget);
    expect(find.text('ยูโอบี'), findsOneWidget);
    expect(find.text('ซีไอเอ็มบี ไทย'), findsOneWidget);
    expect(find.text('แลนด์ แอนด์ เฮ้าส์'), findsOneWidget);
    expect(find.text('ทิสโก้'), findsOneWidget);
    expect(find.text('ไทยเครดิต'), findsOneWidget);
    expect(find.text('ช้อปปี้เพย์'), findsOneWidget);

    // Verify App Names
    expect(find.text('K PLUS • Kasikornbank'), findsOneWidget);
    expect(find.text('SCB EASY • แม่มณี'), findsOneWidget);
    expect(find.text('KMA • Bank of Ayudhya'), findsOneWidget);
    expect(find.text('TrueMoney Wallet'), findsOneWidget);
    expect(find.text('Krungthai NEXT'), findsOneWidget);
    expect(find.text('ttb touch'), findsOneWidget);
    expect(find.text('Bangkok Bank • Bualuang mBanking'), findsOneWidget);
    expect(find.text('MyMo by GSB'), findsOneWidget);
    expect(find.text('Dime! • KKP Mobile'), findsOneWidget);
    expect(find.text('BAAC Mobile • A-Mobile Plus'), findsOneWidget);
    expect(find.text('UOB TMRW Thailand'), findsOneWidget);
    expect(find.text('CIMB THAI Digital Banking'), findsOneWidget);
    expect(find.text('LHB You • LH Bank'), findsOneWidget);
    expect(find.text('TISCO My Car / Mobile'), findsOneWidget);
    expect(find.text('Thai Credit Alpha'), findsOneWidget);
    expect(find.text('ShopeePay • SeaMoney'), findsOneWidget);

    // Verify switches exist for all 16 banks
    expect(find.byType(Switch), findsNWidgets(16));
  });

  testWidgets('Toggling switch disables bank and updates AppSettings', (tester) async {
    tester.view.physicalSize = const Size(800, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(buildTestWidget());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Initially 16 active
    expect(find.text('16 ธนาคาร'), findsOneWidget);

    // Tap first switch (KBank)
    await tester.tap(find.byType(Switch).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Now 15 active
    expect(find.text('15/16 ธนาคาร'), findsOneWidget);
    expect(find.text('ปิดอยู่'), findsOneWidget);

    // Tap 'เปิดทั้งหมด' to re-enable
    await tester.tap(find.text('เปิดทั้งหมด'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('16 ธนาคาร'), findsOneWidget);
  });
}

