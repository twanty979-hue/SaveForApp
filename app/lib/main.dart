import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'core/theme/app_theme.dart';
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
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SaveFor',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      // หากพบประวัติล็อกอินคาไว้ในมือถือ ให้เด้งข้ามหน้าเข้าสู่ระบบไปทำงานที่ Dashboard ได้ทันที
      home: AuthSession.isLoggedIn ? const DashboardScreen() : const AuthScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
