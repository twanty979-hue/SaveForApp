import 'dart:convert';
import 'package:app/core/localization/app_material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/theme/app_theme.dart';
import 'core/settings/app_settings.dart';
import 'core/notifications/notification_service.dart';
import 'core/network/api_client.dart';
import 'features/auth/domain/auth_session.dart';
import 'features/auth/presentation/auth_screen.dart';
import 'features/dashboard/presentation/dashboard_screen.dart';

// ตรวจสอบและล็อกอินผู้ใช้ตั้งแต่เปิดแอปทันทีเพื่อป้องกันบราวเซอร์สับสนพอร์ตเราท์เตอร์ (#access_token)
Future<void> _checkInitialTokens() async {
  String? accessToken;
  String? refreshToken;

  // 1. วิเคราะห์ข้อมูลจาก Hash Fragment (#)
  final fragment = Uri.base.fragment;
  if (fragment.isNotEmpty) {
    String cleanFragment = fragment;
    if (cleanFragment.startsWith('/')) {
      cleanFragment = cleanFragment.substring(1);
    }
    if (cleanFragment.contains('?')) {
      cleanFragment = cleanFragment.substring(cleanFragment.indexOf('?') + 1);
    }
    if (cleanFragment.contains('#')) {
      cleanFragment = cleanFragment.substring(cleanFragment.indexOf('#') + 1);
    }
    final params = Uri.splitQueryString(cleanFragment);
    accessToken = params['access_token'];
    refreshToken = params['refresh_token'];
  }

  // 2. วิเคราะห์ข้อมูลจาก Query Parameters (?)
  if (accessToken == null || accessToken.isEmpty) {
    accessToken = Uri.base.queryParameters['access_token'];
    refreshToken = Uri.base.queryParameters['refresh_token'];
  }

  if (accessToken != null && accessToken.isNotEmpty) {
    try {
      final apiClient = ApiClient();
      final response = await apiClient.get(
        '/auth/user',
        headers: {'Authorization': 'Bearer $accessToken'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final id = data['id']?.toString();
        final email = data['email']?.toString();
        final userMetadata = data['user_metadata'] as Map<String, dynamic>?;
        final displayName = userMetadata?['full_name']?.toString() ?? userMetadata?['name']?.toString();
        final googleAvatar = userMetadata?['avatar_url']?.toString();

        if (id != null && id.isNotEmpty) {
          await AuthSession.save(
            id,
            displayName,
            email,
            token: accessToken,
            refresh: refreshToken,
          );
          if (googleAvatar != null && googleAvatar.isNotEmpty) {
            await AuthSession.setAvatarUrl(googleAvatar);
          }
        }
      }
    } catch (_) {
      // ดักจับข้อยกเว้นหากเกิดข้อผิดพลาดในการโหลดเครือข่าย
    }
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    // กรณีหาไฟล์ไม่เจอ
  }

  // 1. เรียกคืนเซสชันล็อกอินเดิม
  await AuthSession.init();
  await AppSettings.init();

  // 2. ดักจับคิวรีส่งกลับจาก OAuth / Magic Link ทันทีก่อน MaterialApp จะประมวลผลเส้นทางชนบั๊กจอขาว
  await _checkInitialTokens();

  // 3. เริ่มต้นระบบแจ้งเตือน
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
            // หน้าเริ่มต้นหลัก
            home: AuthSession.isLoggedIn
                ? const DashboardScreen()
                : const AuthScreen(),
            // ป้องกันเบราว์เซอร์สับสนเส้นทางจาก Hash Fragment คีย์ความปลอดภัย ให้เด้งกลับหน้าหลักแทน
            onUnknownRoute: (settings) {
              return MaterialPageRoute(
                builder: (context) => AuthSession.isLoggedIn
                    ? const DashboardScreen()
                    : const AuthScreen(),
              );
            },
            debugShowCheckedModeBanner: false,
          ),
        ),
      ),
    );
  }
}
