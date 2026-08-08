import 'package:app/core/localization/app_material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/theme/app_theme.dart';
import 'core/settings/app_settings.dart';
import 'core/notifications/notification_service.dart';
import 'features/auth/domain/auth_session.dart';
import 'features/auth/presentation/auth_screen.dart';
import 'features/dashboard/presentation/dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    // กรณีหาไฟล์ไม่เจอ
  }

  // เรียกคืนข้อมูลเซสชันเข้าสู่ระบบของผู้ใช้ที่บันทึกถาวรไว้ในมือถือ (Auto Login)
  await AuthSession.init();
  await AppSettings.init();
  await NotificationService.instance.initialize();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale>(
      valueListenable: AppSettings.locale,
      builder: (context, locale, _) => ValueListenableBuilder<ThemeStyle>(
        valueListenable: AppSettings.themeStyle,
        builder: (context, themeStyle, _) => ValueListenableBuilder<ThemeMode>(
          valueListenable: AppSettings.themeMode,
          builder: (context, themeMode, _) => MaterialApp(
            title: 'SaveFor',
            locale: locale,
            supportedLocales: const [Locale('th'), Locale('en')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            theme: AppTheme.getTheme(themeStyle, ThemeMode.light),
            darkTheme: AppTheme.getTheme(themeStyle, ThemeMode.dark),
            themeMode: themeMode,
            // หากพบประวัติล็อกอินคาไว้ในมือถือ ให้เด้งข้ามหน้าเข้าสู่ระบบไปทำงานที่ Dashboard ได้ทันที
            home: AuthSession.isLoggedIn
                ? const DashboardScreen()
                : const AuthScreen(),
            debugShowCheckedModeBanner: false,
          ),
        ),
      ),
    );
  }
}
