import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app/features/auth/presentation/auth_screen.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
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
      home: AuthScreen(),
    );
  }

  testWidgets('On Android: Apple Sign In button is hidden, only Google Sign In is shown', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestWidget());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Apple button MUST NOT be displayed on Android
      expect(find.byKey(const ValueKey('apple_sign_in_button')), findsNothing);

      // Google button is displayed with clear text label
      expect(find.byKey(const ValueKey('google_sign_in_button')), findsOneWidget);
      expect(find.text('เข้าสู่ระบบด้วย Google'), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('On iOS: Both Apple and Google Sign In buttons are displayed side-by-side', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestWidget());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Apple button MUST be displayed on iOS
      expect(find.byKey(const ValueKey('apple_sign_in_button')), findsOneWidget);

      // Google button is also displayed side-by-side
      expect(find.byKey(const ValueKey('google_sign_in_button')), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
