import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app/core/models/bank_rule_model.dart';
import 'package:app/core/services/bank_rules_service.dart';
import 'package:app/core/settings/app_settings.dart';
import 'package:app/features/profile/presentation/privacy_settings_screen.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
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
      home: PrivacySettingsScreen(),
    );
  }

  testWidgets('PrivacySettingsScreen renders Privacy Commitment Banner and security options', (tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(buildTestWidget());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Verify Privacy Commitment Card
    expect(find.text('คำมั่นสัญญาด้านความเป็นส่วนตัว'), findsOneWidget);
    expect(find.text('ปลอดภัยสูงสุดระดับธนาคาร (PDPA Compliant)'), findsOneWidget);
    expect(find.textContaining('สแกนเฉพาะอัลบั้มธนาคาร'), findsOneWidget);
    expect(find.textContaining('ประมวลผลบนเครื่อง (On-Device)'), findsOneWidget);
    expect(find.textContaining('ไม่ขายข้อมูล ไม่ยิงโฆษณา'), findsOneWidget);

    // Verify Bank Slip Access tile
    expect(find.text('ธนาคารที่ให้อ่านสลิป'), findsOneWidget);
    expect(find.text('สแกนเฉพาะ 16/16 อัลบั้มธนาคารที่เปิดใช้งาน'), findsOneWidget);

    // Verify Tiles exist
    expect(find.text('ล็อกแอปก่อนเข้าใช้งาน'), findsOneWidget);
    expect(find.text('ซ่อนยอดเงินในหน้าแรก'), findsOneWidget);
    expect(find.text('นโยบายความเป็นส่วนตัว'), findsOneWidget);
    expect(find.text('ข้อตกลงการใช้งาน'), findsOneWidget);
    expect(find.text('ลบบัญชี'), findsOneWidget);
  });

  testWidgets('Opening Privacy Policy modal displays detailed PDPA bank whitelist points', (tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(buildTestWidget());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Tap Privacy Policy tile
    await tester.tap(find.text('นโยบายความเป็นส่วนตัว'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Verify Bottom Sheet opened with detailed content
    expect(find.text('การคุ้มครองข้อมูลส่วนบุคคลและสิทธิ์การเข้าถึงรูปภาพ'), findsOneWidget);
    expect(find.text('1. สิทธิ์การเข้าถึงเฉพาะอัลบั้มธนาคาร (Strict Whitelist)'), findsOneWidget);
    expect(find.text('2. ประมวลผลบนเครื่อง (On-Device Local Processing)'), findsOneWidget);
    expect(find.text('3. ผู้ใช้มีสิทธิ์ควบคุม 100% (Full User Control)'), findsOneWidget);
    expect(find.text('เข้าใจและรับทราบแล้ว'), findsOneWidget);

    // Tap Understood button to close
    await tester.tap(find.text('เข้าใจและรับทราบแล้ว'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('การคุ้มครองข้อมูลส่วนบุคคลและสิทธิ์การเข้าถึงรูปภาพ'), findsNothing);
  });
}
