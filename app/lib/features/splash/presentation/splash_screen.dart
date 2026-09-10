import 'dart:async';
import 'package:flutter/material.dart';
import '../../auth/domain/auth_session.dart';
import '../../auth/presentation/auth_screen.dart';
import '../../dashboard/presentation/dashboard_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeInOut,
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.03).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Curves.easeOutCubic,
      ),
    );

    // ให้ภาพ Splash แสดงผลอย่างนุ่มนวลราว 750ms ก่อนเฟดเปลี่ยนเข้าหน้าหลัก
    Timer(const Duration(milliseconds: 750), () {
      if (!mounted) return;
      _animController.forward().then((_) {
        if (!mounted) return;
        final nextScreen = AuthSession.isLoggedIn
            ? const DashboardScreen()
            : const AuthScreen();

        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => nextScreen,
            transitionDuration: const Duration(milliseconds: 350),
            transitionsBuilder: (_, animation, __, child) {
              return FadeTransition(opacity: animation, child: child);
            },
          ),
        );
      });
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F6E9),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ภาพเต็มจอที่กลมกลืนเป็นเนื้อเดียวกันระหว่างโลโก้ ท้องฟ้าครีม และทุ่งหญ้าสีเขียว
          AnimatedBuilder(
            animation: _animController,
            builder: (context, child) {
              return Transform.scale(
                scale: _scaleAnimation.value,
                child: Opacity(
                  opacity: (1.0 - _fadeAnimation.value).clamp(0.0, 1.0),
                  child: child,
                ),
              );
            },
            child: Image.asset(
              'assets/images/splash_artwork.png',
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              alignment: Alignment.center,
            ),
          ),
        ],
      ),
    );
  }
}
