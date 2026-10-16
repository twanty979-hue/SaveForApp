import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';

import 'web_history.dart';

const webLoginPath = '/login';
const webPrivacyPath = '/privacy';
const webTermsPath = '/terms';
const webSupportPath = '/support';
const webDeleteAccountPath = '/delete-account';

class WebLandingScreen extends StatelessWidget {
  const WebLandingScreen({super.key});

  static const _navy = Color(0xFF0F172A);
  static const _ink = Color(0xFF0B192C);
  static const _muted = Color(0xFF64748B);
  static const _background = Color(0xFFF8FAFC);

  @override
  Widget build(BuildContext context) {
    final featuresKey = GlobalKey();

    return Scaffold(
      backgroundColor: _background,
      body: SelectionArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: _Header(
                onFeaturesPressed: () {
                  final target = featuresKey.currentContext;
                  if (target != null) {
                    Scrollable.ensureVisible(
                      target,
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeOutCubic,
                    );
                  }
                },
                onLoginPressed: () => _openLogin(context),
              ),
            ),
            SliverToBoxAdapter(
              child: _Hero(onLoginPressed: () => _openLogin(context)),
            ),
            SliverToBoxAdapter(
              child: KeyedSubtree(
                key: featuresKey,
                child: const _FeaturesSection(),
              ),
            ),
            SliverToBoxAdapter(
              child: _TrustSection(onLoginPressed: () => _openLogin(context)),
            ),
            SliverToBoxAdapter(
              child: _Footer(
                onPrivacyPressed: () => _openRoute(context, webPrivacyPath),
                onTermsPressed: () => _openRoute(context, webTermsPath),
                onSupportPressed: () => _openRoute(context, webSupportPath),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openLogin(BuildContext context) {
    _openRoute(context, webLoginPath);
  }

  void _openRoute(BuildContext context, String path) {
    pushWebPath(path);
    Navigator.of(context).pushNamed(path);
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.onFeaturesPressed,
    required this.onLoginPressed,
  });

  final VoidCallback onFeaturesPressed;
  final VoidCallback onLoginPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        border: Border(
          bottom: BorderSide(
            color: const Color(0xFFE2E8F0).withValues(alpha: 0.8),
          ),
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
            child: Row(
              children: [
                // Logo Icon with Gradient
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF00A88F), Color(0xFF06B6D4)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00A88F).withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'เงินมานี่',
                          style: TextStyle(
                            color: WebLandingScreen._navy,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'PRO',
                            style: TextStyle(
                              color: Color(0xFF059669),
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'NgenManee Personal Finance',
                      style: TextStyle(
                        color: WebLandingScreen._muted.withValues(alpha: 0.8),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                if (MediaQuery.sizeOf(context).width >= 650) ...[
                  TextButton.icon(
                    onPressed: onFeaturesPressed,
                    icon: const Icon(Icons.stars_rounded, size: 18),
                    label: const Text(
                      'ฟีเจอร์เด่น',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                FilledButton.icon(
                  onPressed: onLoginPressed,
                  icon: const Icon(Icons.login_rounded, size: 18),
                  label: const Text(
                    'เข้าสู่ระบบ / เริ่มใช้งาน',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: WebLandingScreen._navy,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.onLoginPressed});

  final VoidCallback onLoginPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFF0FDF4), Color(0xFFF8FAFC), Color(0xFFF0F9FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 56, 28, 72),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 960;
                final copy = Column(
                  crossAxisAlignment: compact
                      ? CrossAxisAlignment.center
                      : CrossAxisAlignment.start,
                  children: [
                    // Top Announcement Tag
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Color(0xFF10B981),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            '✨ จัดการการเงินยุคใหม่ • สแกนสลิปออโต้ใน 0.2 วิ',
                            style: TextStyle(
                              color: WebLandingScreen._navy,
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Main Headline with Gradient
                    RichText(
                      textAlign: compact ? TextAlign.center : TextAlign.left,
                      text: TextSpan(
                        style: const TextStyle(
                          color: WebLandingScreen._ink,
                          fontSize: 48,
                          height: 1.15,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1.5,
                        ),
                        children: [
                          const TextSpan(text: 'เงินมานี่\n'),
                          WidgetSpan(
                            child: ShaderMask(
                              shaderCallback: (bounds) => const LinearGradient(
                                colors: [Color(0xFF00A88F), Color(0xFF0284C7)],
                              ).createShader(bounds),
                              child: const Text(
                                'บันทึกง่าย เงินไหลมาเทมา',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 48,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -1.5,
                                  height: 1.15,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Value Proposition Subtext
                    Text(
                      'แอปพลิเคชันจัดการการเงินส่วนบุคคลที่จะเปลี่ยนความยุ่งยากให้เป็นเรื่องสนุก แค่แนบสลิปโอนเงิน ระบบจะอ่านยอดและบันทึกให้อัตโนมัติ พร้อมกระปุกออมเงินตามฝัน และแดชบอร์ดสรุปรายรับ-รายจ่ายที่เห็นภาพชัดเจนที่สุด',
                      textAlign: compact ? TextAlign.center : TextAlign.left,
                      style: const TextStyle(
                        color: WebLandingScreen._muted,
                        fontSize: 17,
                        height: 1.65,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Action Buttons
                    Wrap(
                      alignment: compact
                          ? WrapAlignment.center
                          : WrapAlignment.start,
                      spacing: 14,
                      runSpacing: 12,
                      children: [
                        FilledButton.icon(
                          onPressed: onLoginPressed,
                          icon: const Icon(Icons.arrow_forward_rounded, size: 20),
                          label: const Text(
                            'เริ่มใช้งานฟรีทันที',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF00A88F),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 26,
                              vertical: 18,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 4,
                            shadowColor: const Color(0xFF00A88F).withValues(alpha: 0.4),
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _showComingSoon(context),
                          icon: const Icon(Icons.apple_rounded, size: 22),
                          label: const Text(
                            'ดาวน์โหลดแอป iOS & Android',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: WebLandingScreen._navy,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 22,
                              vertical: 18,
                            ),
                            side: const BorderSide(
                              color: Color(0xFFCBD5E1),
                              width: 1.5,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            backgroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 36),

                    // Trust Proof Strip
                    Wrap(
                      alignment: compact
                          ? WrapAlignment.center
                          : WrapAlignment.start,
                      spacing: 24,
                      runSpacing: 12,
                      children: [
                        _buildTrustBadge(
                          Icons.bolt_rounded,
                          'สแกนสลิปออโต้',
                          const Color(0xFF00A88F),
                        ),
                        _buildTrustBadge(
                          Icons.shield_rounded,
                          'มาตรฐานความปลอดภัย PDPA',
                          const Color(0xFF0284C7),
                        ),
                        _buildTrustBadge(
                          Icons.savings_rounded,
                          'กระปุกออมเงิน Dreams',
                          const Color(0xFFF59E0B),
                        ),
                      ],
                    ),
                  ],
                );

                // Right Side: Animated Smartphone Showcase
                const visual = _AnimatedAppShowcase();

                if (compact) {
                  return Column(
                    children: [copy, const SizedBox(height: 50), visual],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(flex: 6, child: copy),
                    const SizedBox(width: 48),
                    const Expanded(flex: 5, child: Center(child: visual)),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTrustBadge(IconData icon, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF475569),
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: WebLandingScreen._navy,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: const Row(
          children: [
            Icon(Icons.stars_rounded, color: Color(0xFF10B981)),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'แอป เงินมานี่ กำลังอยู่ระหว่างการตรวจสอบบน App Store & Play Store เร็วๆ นี้ครับ!',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Animated interactive smartphone mockup showing live features of เงินมานี่
class _AnimatedAppShowcase extends StatefulWidget {
  const _AnimatedAppShowcase();

  @override
  State<_AnimatedAppShowcase> createState() => _AnimatedAppShowcaseState();
}

class _AnimatedAppShowcaseState extends State<_AnimatedAppShowcase>
    with TickerProviderStateMixin {
  late final AnimationController _floatController;
  late final AnimationController _scanController;
  int _activeDemoIndex = 0; // 0 = Slip Scan, 1 = Dreams, 2 = Dashboard
  Timer? _cycleTimer;

  @override
  void initState() {
    super.initState();
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat(reverse: true);

    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();

    // Auto cycle through the 3 demos every 4.5 seconds
    _cycleTimer = Timer.periodic(const Duration(milliseconds: 4500), (timer) {
      if (mounted) {
        setState(() {
          _activeDemoIndex = (_activeDemoIndex + 1) % 3;
        });
      }
    });
  }

  @override
  void dispose() {
    _floatController.dispose();
    _scanController.dispose();
    _cycleTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _floatController,
      builder: (context, child) {
        final floatOffset = math.sin(_floatController.value * math.pi) * 8.0;
        return Transform.translate(
          offset: Offset(0, floatOffset),
          child: child,
        );
      },
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // Ambient Glow behind the Phone
          Positioned(
            child: Container(
              width: 340,
              height: 520,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF00A88F).withValues(alpha: 0.22),
                    const Color(0xFF06B6D4).withValues(alpha: 0.15),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Main Smartphone Chassis
          Container(
            width: 330,
            height: 610,
            decoration: BoxDecoration(
              color: const Color(0xFF0B132B),
              borderRadius: BorderRadius.circular(46),
              border: Border.all(
                color: const Color(0xFF334155),
                width: 6,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.28),
                  blurRadius: 36,
                  offset: const Offset(0, 20),
                ),
                BoxShadow(
                  color: const Color(0xFF00A88F).withValues(alpha: 0.18),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(40),
              child: Container(
                color: const Color(0xFF0F172A),
                child: Column(
                  children: [
                    // Dynamic Island & Status Bar
                    _buildStatusBar(),

                    // In-App Screen Content
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 8),
                            // User Greeting & Balance Card
                            _buildAppHeader(),
                            const SizedBox(height: 12),
                            _buildBalanceCard(),
                            const SizedBox(height: 14),

                            // Interactive Feature Mode Selector
                            _buildModeSelector(),
                            const SizedBox(height: 12),

                            // Dynamic Animated Feature Content
                            Expanded(child: _buildActiveDemoContent()),
                          ],
                        ),
                      ),
                    ),

                    // In-App Bottom Navigation Bar
                    _buildInAppNavBar(),
                  ],
                ),
              ),
            ),
          ),

          // Floating Pill 1: Top-Left (สแกนสลิปอัจฉริยะ)
          Positioned(
            top: 40,
            left: -32,
            child: _buildFloatingBadge(
              icon: Icons.qr_code_scanner_rounded,
              iconColor: const Color(0xFF10B981),
              title: 'สแกนสลิปออโต้',
              subtitle: 'ดึงยอดทันทีใน 0.2 วิ',
            ),
          ),

          // Floating Pill 2: Bottom-Right (ความปลอดภัย)
          Positioned(
            bottom: 60,
            right: -32,
            child: _buildFloatingBadge(
              icon: Icons.lock_outline_rounded,
              iconColor: const Color(0xFF06B6D4),
              title: 'ระบบปลอดภัยสูงสุด',
              subtitle: 'Face ID & มาตรฐาน PDPA',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            '09:41',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          // Dynamic Island Pill
          Container(
            width: 88,
            height: 22,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(
              child: Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: Color(0xFF1E293B),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          const Row(
            children: [
              Icon(Icons.wifi, color: Colors.white, size: 13),
              SizedBox(width: 4),
              Icon(Icons.battery_full_rounded, color: Color(0xFF10B981), size: 14),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAppHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFF00A88F), Color(0xFF10B981)],
                ),
                border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
              ),
              child: const Center(
                child: Text('เงิน', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'เงินมานี่ PRO',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'พร้อมใช้งานวันนี้ ✨',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.notifications_none_rounded, color: Colors.white, size: 16),
        ),
      ],
    );
  }

  Widget _buildBalanceCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF00A88F), Color(0xFF0D9488), Color(0xFF0F766E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00A88F).withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ยอดเงินคงเหลือสุทธิ',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.trending_up_rounded, color: Color(0xFF6EE7B7), size: 12),
                    SizedBox(width: 3),
                    Text('+18.4%', style: TextStyle(color: Color(0xFF6EE7B7), fontSize: 10, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            '฿48,500.00',
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSubStat('รายรับเดือนนี้', '+฿52,000', const Color(0xFF86EFAC)),
                Container(width: 1, height: 16, color: Colors.white.withValues(alpha: 0.2)),
                _buildSubStat('รายจ่ายเดือนนี้', '-฿3,500', const Color(0xFFFCA5A5)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubStat(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 9)),
        Text(value, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800)),
      ],
    );
  }

  Widget _buildModeSelector() {
    final modes = [
      (Icons.qr_code_scanner_rounded, 'สแกนสลิป'),
      (Icons.savings_rounded, 'เป้าหมายออม'),
      (Icons.bar_chart_rounded, 'แดชบอร์ด'),
    ];

    return Row(
      children: [
        for (int i = 0; i < modes.length; i++)
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() => _activeDemoIndex = i);
              },
              child: Container(
                margin: EdgeInsets.only(right: i < 2 ? 6 : 0),
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: _activeDemoIndex == i
                      ? const Color(0xFF00A88F).withValues(alpha: 0.2)
                      : Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _activeDemoIndex == i
                        ? const Color(0xFF00A88F)
                        : Colors.transparent,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      modes[i].$1,
                      size: 13,
                      color: _activeDemoIndex == i
                          ? const Color(0xFF14B8A6)
                          : Colors.white.withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      modes[i].$2,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: _activeDemoIndex == i
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildActiveDemoContent() {
    switch (_activeDemoIndex) {
      case 0:
        return _buildSlipScanDemo();
      case 1:
        return _buildDreamsDemo();
      default:
        return _buildDashboardDemo();
    }
  }

  /// Demo 1: Animated Slip Scan Experience
  Widget _buildSlipScanDemo() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 16),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ตรวจจับสลิปโอนเงินสำเร็จ!', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                    Text('บันทึกลงรายจ่ายอัตโนมัติทันที', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 9)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Slip Visual simulation
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF00A88F).withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.coffee_rounded, color: Color(0xFFF59E0B), size: 18),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('ชาตรามือ (สาขาสยาม)', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                      Text('สแกนจากสลิป K PLUS', style: TextStyle(color: Color(0xFF64748B), fontSize: 9)),
                    ],
                  ),
                ),
                const Text(
                  '-฿55.00',
                  style: TextStyle(
                    color: Color(0xFFF43F5E),
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF00A88F).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text('⚡ ใช้เวลาวิเคราะห์เพียง 0.24 วินาที', style: TextStyle(color: Color(0xFF2DD4BF), fontSize: 9, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  /// Demo 2: Animated Dreams / Savings Goals
  Widget _buildDreamsDemo() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Text('🇯🇵', style: TextStyle(fontSize: 16)),
                  SizedBox(width: 6),
                  Text('ทริปเที่ยวญี่ปุ่น', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('68% ถึงฝัน', style: TextStyle(color: Color(0xFFF59E0B), fontSize: 9, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Stack(
              children: [
                Container(height: 8, color: const Color(0xFF334155)),
                FractionallySizedBox(
                  widthFactor: 0.68,
                  child: Container(
                    height: 8,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF00A88F), Color(0xFFF59E0B)],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('฿34,000 เก็บแล้ว', style: TextStyle(color: Color(0xFF34D399), fontSize: 9, fontWeight: FontWeight.bold)),
              Text('เป้าหมาย ฿50,000', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 9)),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 14),
                SizedBox(width: 6),
                Expanded(
                  child: Text('เหลืออีกเพียง ฿16,000 จะพิชิตเป้าหมายนี้!', style: TextStyle(color: Colors.white, fontSize: 9)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Demo 3: Recent Transactions & Analytics
  Widget _buildDashboardDemo() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('รายการล่าสุดวันนี้', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          _buildTxItem(Icons.work_rounded, 'เงินเดือนประจำงวด', '+฿35,000.00', const Color(0xFF10B981), true),
          const SizedBox(height: 6),
          _buildTxItem(Icons.restaurant_rounded, 'มื้อเที่ยง ข้าวมันไก่', '-฿80.00', const Color(0xFFF59E0B), false),
          const SizedBox(height: 6),
          _buildTxItem(Icons.shopping_bag_rounded, 'ซื้อของเข้าบ้าน', '-฿320.00', const Color(0xFFA855F7), false),
        ],
      ),
    );
  }

  Widget _buildTxItem(IconData icon, String title, String amount, Color color, bool isIncome) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, color: color, size: 13),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            amount,
            style: TextStyle(
              color: isIncome ? const Color(0xFF34D399) : const Color(0xFFF43F5E),
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInAppNavBar() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0B132B),
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildInAppNavIcon(Icons.dashboard_rounded, true),
          _buildInAppNavIcon(Icons.receipt_long_rounded, false),
          // Center Scan Button with glowing gradient
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF00A88F), Color(0xFF06B6D4)],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00A88F).withValues(alpha: 0.4),
                  blurRadius: 8,
                ),
              ],
            ),
            child: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
          ),
          _buildInAppNavIcon(Icons.savings_rounded, false),
          _buildInAppNavIcon(Icons.person_rounded, false),
        ],
      ),
    );
  }

  Widget _buildInAppNavIcon(IconData icon, bool active) {
    return Icon(
      icon,
      color: active ? const Color(0xFF00A88F) : const Color(0xFF64748B),
      size: 18,
    );
  }

  Widget _buildFloatingBadge({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF0F172A),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FeaturesSection extends StatelessWidget {
  const _FeaturesSection();

  @override
  Widget build(BuildContext context) {
    const features = [
      (
        Icons.qr_code_scanner_rounded,
        'สแกนสลิปอัจฉริยะ (Slip OCR)',
        'ไม่ต้องพิมพ์เองให้เมื่อย แค่เลือกภาพสลิปโอนเงิน ระบบดึงยอด วันที่ และเวลาบันทึกให้อัตโนมัติใน 0.2 วินาที',
        Color(0xFF00A88F),
      ),
      (
        Icons.savings_rounded,
        'กระปุกออมเงินตามฝัน (Dreams)',
        'ตั้งเป้าหมายการเงิน ไม่ว่าจะเป็นทริปเที่ยว แต่งงาน ซื้อบ้าน หรือเงินสำรอง พร้อมแถบความคืบหน้าสร้างพลังใจ',
        Color(0xFFF59E0B),
      ),
      (
        Icons.calendar_month_rounded,
        'วางแผนเงินล่วงหน้า (Planning Hub)',
        'จัดการค่าใช้จ่ายประจำ เช่น ค่าเช่า ค่าน้ำ ค่าไฟ หรือเงินเดือนล่วงหน้า ไม่พลาดทุกรายจ่ายสำคัญ',
        Color(0xFF0284C7),
      ),
      (
        Icons.insights_rounded,
        'แดชบอร์ดวิเคราะห์ 12 เดือน',
        'ดูกราฟเปรียบเทียบรายรับ-รายจ่ายย้อนหลัง สรุปหมวดหมู่ที่ใช้เงินมากที่สุด เพื่อช่วยให้คุณคุมงบได้อยู่หมัด',
        Color(0xFF8B5CF6),
      ),
      (
        Icons.fingerprint_rounded,
        'ปลอดภัยด้วย Face ID / สแกนนิ้ว',
        'ปกป้องข้อมูลการเงินส่วนตัวด้วยระบบล็อกไบโอเมตริกซ์ มาตรฐาน PDPA ปลอดภัย ไร้กังวล',
        Color(0xFF10B981),
      ),
      (
        Icons.devices_rounded,
        'ซิงค์ทุกอุปกรณ์ Real-time',
        'ใช้งานได้อย่างไร้รอยต่อทั้งบนมือถือ iOS, Android และหน้าเว็บเบราว์เซอร์ ข้อมูลอัปเดตตรงกันตลอดเวลา',
        Color(0xFFEC4899),
      ),
    ];

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 64, 28, 78),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF00A88F).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: const Text(
                  'ฟีเจอร์เด่นระดับพรีเมียม',
                  style: TextStyle(
                    color: Color(0xFF00A88F),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'ครบจบทุกเรื่องการเงินในแอปเดียว',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: WebLandingScreen._ink,
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.8,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'ออกแบบมาให้ใช้งานง่าย รวดเร็ว และตอบโจทย์วิถีชีวิตคนยุคใหม่ที่ต้องการมีเงินเก็บเพิ่มขึ้นจริง',
                textAlign: TextAlign.center,
                style: TextStyle(color: WebLandingScreen._muted, fontSize: 16),
              ),
              const SizedBox(height: 42),
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 900
                      ? 3
                      : (constraints.maxWidth >= 600 ? 2 : 1);
                  return GridView.count(
                    crossAxisCount: columns,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 20,
                    crossAxisSpacing: 20,
                    childAspectRatio: columns == 3 ? 1.25 : (columns == 2 ? 1.3 : 2.0),
                    children: [
                      for (final feature in features)
                        _FeatureCard(
                          icon: feature.$1,
                          title: feature.$2,
                          description: feature.$3,
                          accentColor: feature.$4,
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.accentColor,
  });

  final IconData icon;
  final String title;
  final String description;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: accentColor, size: 26),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            style: const TextStyle(
              color: WebLandingScreen._ink,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            description,
            style: const TextStyle(
              color: WebLandingScreen._muted,
              fontSize: 14,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}

class _TrustSection extends StatelessWidget {
  const _TrustSection({required this.onLoginPressed});

  final VoidCallback onLoginPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 64, 28, 68),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 720;
                final text = Column(
                  crossAxisAlignment: compact
                      ? CrossAxisAlignment.center
                      : CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'เริ่มสร้างวินัยการเงินและมีเงินเก็บได้แล้ววันนี้',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.6,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'เชื่อมต่อระบบบัญชี เงินมานี่ เริ่มต้นได้ฟรีโดยไม่มีข้อผูกมัด ปลอดภัยด้วยการเข้ารหัสระดับสูง',
                      textAlign: compact ? TextAlign.center : TextAlign.left,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 16,
                        height: 1.55,
                      ),
                    ),
                  ],
                );
                final button = FilledButton.icon(
                  onPressed: onLoginPressed,
                  icon: const Icon(Icons.rocket_launch_rounded, size: 20),
                  label: const Text(
                    'เข้าสู่ระบบ / สมัครสมาชิกฟรี',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF00A88F),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 26,
                      vertical: 18,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 4,
                  ),
                );
                return compact
                    ? Column(
                        children: [text, const SizedBox(height: 28), button],
                      )
                    : Row(
                        children: [
                          Expanded(child: text),
                          const SizedBox(width: 28),
                          button,
                        ],
                      );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({
    required this.onPrivacyPressed,
    required this.onTermsPressed,
    required this.onSupportPressed,
  });

  final VoidCallback onPrivacyPressed;
  final VoidCallback onTermsPressed;
  final VoidCallback onSupportPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 30, 28, 36),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              runSpacing: 18,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '© 2026 เงินมานี่ (NgenManee) • All rights reserved',
                      style: TextStyle(
                        color: WebLandingScreen._muted,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'แอปพลิเคชันบันทึกรายรับ-รายจ่าย และจัดการการเงินส่วนบุคคล',
                      style: TextStyle(
                        color: WebLandingScreen._muted.withValues(alpha: 0.7),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 12,
                  children: [
                    TextButton(
                      onPressed: onPrivacyPressed,
                      child: const Text('นโยบายความเป็นส่วนตัว (Privacy)'),
                    ),
                    TextButton(
                      onPressed: onTermsPressed,
                      child: const Text('เงื่อนไขการใช้งาน (Terms)'),
                    ),
                    TextButton(
                      onPressed: onSupportPressed,
                      child: const Text('ติดต่อเรา (Support)'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class WebDocumentScreen extends StatelessWidget {
  const WebDocumentScreen({required this.title, required this.paragraphs});

  final String title;
  final List<String> paragraphs;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: IconButton(
          tooltip: 'กลับหน้าหลัก',
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            replaceWebPath('/');
            final navigator = Navigator.of(context);
            if (navigator.canPop()) {
              navigator.pop();
            } else {
              navigator.pushReplacementNamed('/');
            }
          },
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: ListView.separated(
            padding: const EdgeInsets.all(28),
            itemCount: paragraphs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 18),
            itemBuilder: (_, index) => Text(
              paragraphs[index],
              style: const TextStyle(
                color: WebLandingScreen._ink,
                fontSize: 16,
                height: 1.7,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
