import 'package:flutter/material.dart';

import 'web_history.dart';

const webLoginPath = '/login';
const webPrivacyPath = '/privacy';
const webTermsPath = '/terms';
const webSupportPath = '/support';
const webDeleteAccountPath = '/delete-account';

class WebLandingScreen extends StatelessWidget {
  const WebLandingScreen({super.key});

  static const _navy = Color(0xFF123B7A);
  static const _teal = Color(0xFF16B8A5);
  static const _ink = Color(0xFF10233F);
  static const _muted = Color(0xFF607089);
  static const _background = Color(0xFFF7FAFD);

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
                      duration: const Duration(milliseconds: 500),
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
                onPrivacyPressed: () =>
                    _openRoute(context, webPrivacyPath),
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
      color: Colors.white,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
            child: Row(
              children: [
                const Icon(
                  Icons.account_balance_wallet_rounded,
                  color: WebLandingScreen._teal,
                  size: 30,
                ),
                const SizedBox(width: 10),
                const Text(
                  'SaveFor',
                  style: TextStyle(
                    color: WebLandingScreen._navy,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.6,
                  ),
                ),
                const Spacer(),
                if (MediaQuery.sizeOf(context).width >= 650) ...[
                  TextButton(
                    onPressed: onFeaturesPressed,
                    child: const Text('ฟีเจอร์'),
                  ),
                  const SizedBox(width: 10),
                ],
                OutlinedButton(
                  onPressed: onLoginPressed,
                  child: const Text('เข้าสู่ระบบ'),
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
          colors: [Color(0xFFEFF8FF), Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 70, 28, 84),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 760;
                final copy = Column(
                  crossAxisAlignment: compact
                      ? CrossAxisAlignment.center
                      : CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: WebLandingScreen._teal.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: const Text(
                        'วางแผนเงินของคุณให้ชัดขึ้น',
                        style: TextStyle(
                          color: WebLandingScreen._navy,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'SaveFor\nเก็บเงินให้ถึงฝัน',
                      textAlign: compact ? TextAlign.center : TextAlign.left,
                      style: const TextStyle(
                        color: WebLandingScreen._ink,
                        fontSize: 50,
                        height: 1.08,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1.8,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'บันทึกรายรับ-รายจ่าย วางเป้าหมาย และติดตามความคืบหน้าการออมในที่เดียว ออกแบบมาให้ใช้ง่ายและเห็นภาพการเงินของตัวเองมากขึ้น',
                      textAlign: compact ? TextAlign.center : TextAlign.left,
                      style: TextStyle(
                        color: WebLandingScreen._muted,
                        fontSize: 18,
                        height: 1.65,
                      ),
                    ),
                    const SizedBox(height: 30),
                    Wrap(
                      alignment: compact
                          ? WrapAlignment.center
                          : WrapAlignment.start,
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        FilledButton.icon(
                          onPressed: onLoginPressed,
                          icon: const Icon(Icons.arrow_forward_rounded),
                          label: const Text('เริ่มใช้งาน'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _showComingSoon(context),
                          icon: const Icon(Icons.download_rounded),
                          label: const Text('ดาวน์โหลดแอป'),
                        ),
                      ],
                    ),
                  ],
                );

                final visual = Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x1A123B7A),
                        blurRadius: 34,
                        offset: Offset(0, 18),
                      ),
                    ],
                  ),
                  child: Image.asset(
                    'assets/images/logo_blue.png',
                    width: compact ? 250 : 360,
                    height: compact ? 250 : 360,
                    fit: BoxFit.contain,
                  ),
                );

                if (compact) {
                  return Column(
                    children: [copy, const SizedBox(height: 42), visual],
                  );
                }
                return Row(
                  children: [
                    Expanded(flex: 6, child: copy),
                    const SizedBox(width: 70),
                    Expanded(flex: 4, child: visual),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('ลิงก์ดาวน์โหลดจะเปิดเมื่อแอปพร้อมเผยแพร่บน Store'),
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
        Icons.receipt_long_rounded,
        'บันทึกเงินได้ง่าย',
        'ติดตามรายรับ รายจ่าย และรายการประจำในมุมมองที่เข้าใจง่าย',
      ),
      (
        Icons.flag_rounded,
        'เป้าหมายที่จับต้องได้',
        'สร้างความฝัน ตั้งยอดเป้าหมาย และดูความคืบหน้าการออม',
      ),
      (
        Icons.insights_rounded,
        'เห็นภาพการเงิน',
        'สรุปข้อมูลสำคัญให้ตัดสินใจเรื่องเงินในแต่ละเดือนได้ดีขึ้น',
      ),
    ];

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1180),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 76, 28, 78),
          child: Column(
            children: [
              const Text(
                'ทุกบาทมีเป้าหมาย',
                style: TextStyle(
                  color: WebLandingScreen._ink,
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'เครื่องมือเล็ก ๆ ที่ช่วยให้การออมเป็นเรื่องที่ทำต่อเนื่องได้จริง',
                textAlign: TextAlign.center,
                style: TextStyle(color: WebLandingScreen._muted, fontSize: 16),
              ),
              const SizedBox(height: 34),
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 850 ? 3 : 1;
                  return GridView.count(
                    crossAxisCount: columns,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 18,
                    crossAxisSpacing: 18,
                    childAspectRatio: columns == 3 ? 1.15 : 2.4,
                    children: [
                      for (final feature in features)
                        _FeatureCard(
                          icon: feature.$1,
                          title: feature.$2,
                          description: feature.$3,
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
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: WebLandingScreen._teal.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: WebLandingScreen._teal, size: 24),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: const TextStyle(
                color: WebLandingScreen._ink,
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              description,
              style: const TextStyle(
                color: WebLandingScreen._muted,
                height: 1.55,
              ),
            ),
          ],
        ),
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
      color: WebLandingScreen._navy,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 54, 28, 58),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 720;
                final text = Column(
                  crossAxisAlignment: compact
                      ? CrossAxisAlignment.center
                      : CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'เริ่มดูแลเงินของคุณวันนี้',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'ข้อมูลของคุณเชื่อมต่อผ่านระบบบัญชีของ SaveFor และออกแบบให้คุณเริ่มต้นได้โดยไม่ซับซ้อน',
                      textAlign: compact ? TextAlign.center : TextAlign.left,
                      style: const TextStyle(
                        color: Color(0xC7FFFFFF),
                        height: 1.55,
                      ),
                    ),
                  ],
                );
                final button = FilledButton.icon(
                  onPressed: onLoginPressed,
                  icon: const Icon(Icons.login_rounded),
                  label: const Text('เข้าสู่ระบบ SaveFor'),
                  style: FilledButton.styleFrom(
                    backgroundColor: WebLandingScreen._teal,
                  ),
                );
                return compact
                    ? Column(
                        children: [text, const SizedBox(height: 24), button],
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
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 28, 28, 34),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              runSpacing: 18,
              children: [
                const Text(
                  '© 2026 SaveFor',
                  style: TextStyle(color: WebLandingScreen._muted),
                ),
                Wrap(
                  spacing: 6,
                  children: [
                    TextButton(
                      onPressed: onPrivacyPressed,
                      child: const Text('ความเป็นส่วนตัว'),
                    ),
                    TextButton(
                      onPressed: onTermsPressed,
                      child: const Text('เงื่อนไข'),
                    ),
                    TextButton(
                      onPressed: onSupportPressed,
                      child: const Text('ช่วยเหลือ'),
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
