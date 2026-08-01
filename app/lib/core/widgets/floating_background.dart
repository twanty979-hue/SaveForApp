import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class FloatingBackground extends StatefulWidget {
  const FloatingBackground({super.key});

  @override
  State<FloatingBackground> createState() => _FloatingBackgroundState();
}

class _FloatingBackgroundState extends State<FloatingBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final val = _controller.value;
        return Stack(
          children: [
            // ไอคอนเพชร (ขยับขึ้นลงและเอียงเล็กน้อย)
            Positioned(
              top: 100 + (val * 15),
              right: 40 + (val * 5),
              child: Transform.rotate(
                angle: val * 0.2,
                child: const Opacity(
                  opacity: 0.03,
                  child: Icon(Icons.diamond, size: 80, color: AppTheme.primaryColor),
                ),
              ),
            ),
            // ไอคอนรถ (ขยับเยื้องซ้ายขวา)
            Positioned(
              top: 250 - (val * 10),
              left: 30 + (val * 15),
              child: const Opacity(
                opacity: 0.03,
                child: Icon(Icons.directions_car, size: 80, color: AppTheme.primaryColor),
              ),
            ),
            // ไอคอนกระเป๋าตังค์ (หมุนรอบจุดศูนย์กลางช้าๆ)
            Positioned.fill(
              child: Center(
                child: Transform.rotate(
                  angle: val * 2 * math.pi * 0.04,
                  child: const Opacity(
                    opacity: 0.02,
                    child: Icon(Icons.account_balance_wallet, size: 120, color: AppTheme.primaryColor),
                  ),
                ),
              ),
            ),
            // ไอคอนบ้าน (ขยับโยกเยกเบาๆ)
            Positioned(
              bottom: 300 + (val * 12),
              right: 30 - (val * 8),
              child: Transform.rotate(
                angle: -val * 0.1,
                child: const Opacity(
                  opacity: 0.03,
                  child: Icon(Icons.home, size: 90, color: AppTheme.primaryColor),
                ),
              ),
            ),
            // ไอคอนบัตรเครดิต (ขยับลอยละล่อง)
            Positioned(
              bottom: 120 - (val * 12),
              left: 40 + (val * 10),
              child: Transform.rotate(
                angle: val * 0.15,
                child: const Opacity(
                  opacity: 0.03,
                  child: Icon(Icons.credit_card, size: 75, color: AppTheme.primaryColor),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
