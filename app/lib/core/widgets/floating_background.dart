import 'dart:math' as math;
import 'package:app/core/localization/app_material.dart';
import '../theme/app_theme.dart';

class FloatingBackground extends StatefulWidget {
  const FloatingBackground({super.key});

  @override
  State<FloatingBackground> createState() => _FloatingBackgroundState();
}

class _Floater {
  final IconData icon;
  final double x; // Horizontal position fraction (0.0 to 1.0)
  final double relativeY; // Initial vertical position fraction (0.0 to 1.0)
  final double speed; // Speed multiplier (1.0 means it loops once per cycle)
  final double size;
  final double opacity;
  final double rotationPhase;

  const _Floater({
    required this.icon,
    required this.x,
    required this.relativeY,
    required this.speed,
    required this.size,
    required this.opacity,
    required this.rotationPhase,
  });
}

class _FloatingBackgroundState extends State<FloatingBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  // Static list of floating icons with different positions, speeds, and sizes
  static const List<_Floater> _floaters = [
    _Floater(
      icon: Icons.account_balance_wallet_outlined,
      x: 0.15,
      relativeY: 0.8,
      speed: 0.6,
      size: 70,
      opacity: 0.025,
      rotationPhase: 0.2,
    ),
    _Floater(
      icon: Icons.savings_outlined,
      x: 0.75,
      relativeY: 0.4,
      speed: 0.7,
      size: 80,
      opacity: 0.03,
      rotationPhase: 1.5,
    ),
    _Floater(
      icon: Icons.credit_card_outlined,
      x: 0.35,
      relativeY: 0.1,
      speed: 0.55,
      size: 65,
      opacity: 0.02,
      rotationPhase: 0.8,
    ),
    _Floater(
      icon: Icons.diamond_outlined,
      x: 0.85,
      relativeY: 0.9,
      speed: 0.8,
      size: 55,
      opacity: 0.035,
      rotationPhase: 2.3,
    ),
    _Floater(
      icon: Icons.trending_up_outlined,
      x: 0.55,
      relativeY: 0.6,
      speed: 0.65,
      size: 75,
      opacity: 0.025,
      rotationPhase: 3.1,
    ),
    _Floater(
      icon: Icons.payments_outlined,
      x: 0.08,
      relativeY: 0.3,
      speed: 0.5,
      size: 60,
      opacity: 0.02,
      rotationPhase: 1.1,
    ),
    _Floater(
      icon: Icons.storefront_outlined,
      x: 0.65,
      relativeY: 0.25,
      speed: 0.75,
      size: 70,
      opacity: 0.028,
      rotationPhase: 0.5,
    ),
    _Floater(
      icon: Icons.shopping_bag_outlined,
      x: 0.48,
      relativeY: 0.95,
      speed: 0.6,
      size: 65,
      opacity: 0.022,
      rotationPhase: 1.9,
    ),
  ];

  @override
  void initState() {
    super.initState();
    // Continuous loop without reversing
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 25),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;

        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final progress = _controller.value;

            return Stack(
              clipBehavior: Clip.hardEdge,
              children: _floaters.map((floater) {
                // Calculate y coordinate floating upwards (loops from 1.0 to 0.0)
                double currentYRelative = floater.relativeY - (progress * floater.speed);
                // Wrap around between 0.0 and 1.0
                currentYRelative = currentYRelative % 1.0;

                final double y = currentYRelative * (height + floater.size) - floater.size;
                final double x = floater.x * (width - floater.size);

                // Add gentle rotation speed matching the movement
                final double rotation = progress * 2 * math.pi * 0.15 + floater.rotationPhase;

                return Positioned(
                  left: x,
                  top: y,
                  child: Transform.rotate(
                    angle: rotation,
                    child: Opacity(
                      opacity: floater.opacity,
                      child: Icon(
                        floater.icon,
                        size: floater.size,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ),
                );
              }).toList(),
            );
          },
        );
      },
    );
  }
}
