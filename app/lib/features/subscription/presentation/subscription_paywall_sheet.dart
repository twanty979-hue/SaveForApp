import 'package:flutter/services.dart';
import 'package:app/core/localization/app_material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/services/subscription_service.dart';
import '../../../../core/theme/app_theme.dart';

class SubscriptionPaywallSheet extends StatefulWidget {
  final String? featureTriggerReason;

  const SubscriptionPaywallSheet({super.key, this.featureTriggerReason});

  static Future<bool> show(
    BuildContext context, {
    String? reason,
  }) async {
    HapticFeedback.mediumImpact();
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SubscriptionPaywallSheet(featureTriggerReason: reason),
    );
    return result ?? false;
  }

  @override
  State<SubscriptionPaywallSheet> createState() => _SubscriptionPaywallSheetState();
}

class _SubscriptionPaywallSheetState extends State<SubscriptionPaywallSheet> {
  bool _isYearly = true; // Default to best-value yearly plan
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _handlePurchase() async {
    HapticFeedback.selectionClick();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final success = _isYearly
          ? await SubscriptionService.instance.purchaseYearly()
          : await SubscriptionService.instance.purchaseMonthly();

      if (!mounted) return;

      if (success) {
        HapticFeedback.heavyImpact();
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: Row(
              children: [
                const Icon(Icons.stars_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.tr(
                      'ยินดีต้อนรับสู่ SaveFor PRO! ปลดล็อกทุกฟีเจอร์แล้ว 🎉',
                      'Welcome to SaveFor PRO! All features unlocked 🎉',
                    ),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        );
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  Future<void> _handleRestore() async {
    HapticFeedback.lightImpact();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final restored = await SubscriptionService.instance.restorePurchases();
      if (!mounted) return;
      setState(() => _isLoading = false);

      if (restored) {
        HapticFeedback.heavyImpact();
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: Text(
              context.tr(
                'กู้คืนสิทธิ์ SaveFor PRO สำเร็จเรียบร้อย!',
                'SaveFor PRO restored successfully!',
              ),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        );
      } else {
        setState(() {
          _errorMessage = context.tr(
            'ไม่พบรายการสั่งซื้อเดิมในบัญชีนี้',
            'No active subscription found for this account',
          );
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  void _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.92,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131823) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border.all(
          color: isDark ? const Color(0xFF2A364F) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Stack(
        children: [
          // Ambient Glow at the top
          Positioned(
            top: -60,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: 260,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppTheme.primaryColor.withValues(alpha: isDark ? 0.35 : 0.2),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),

          SafeArea(
            top: false,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              physics: const BouncingScrollPhysics(),
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Top Badge & Close button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFFF59E0B),
                            const Color(0xFFD97706),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.stars_rounded, color: Colors.white, size: 14),
                          SizedBox(width: 5),
                          Text(
                            'SAVEFOR PRO',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded, size: 22, color: Color(0xFF94A3B8)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Hero Title & Subtitle
                Text(
                  context.tr(
                    'ปลดล็อกพลังการเงินไร้ขีดจำกัด',
                    'Unlock Full Financial Freedom',
                  ),
                  style: TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.featureTriggerReason ??
                      context.tr(
                        'บันทึก สแกน และวิเคราะห์การเงินครบวงจร ตอบโจทย์ทุกการวางแผนชีวิต',
                        'Scan slips, unlock unlimited history, and gain full financial clarity',
                      ),
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),

                // 5 Feature Highlight Cards
                _FeatureRow(
                  icon: Icons.qr_code_scanner_rounded,
                  iconColor: const Color(0xFF10B981),
                  title: context.tr(
                    'สแกนสลิปย้อนหลังสูงสุด 60 วัน',
                    'Scan slips up to 60 days',
                  ),
                  subtitle: context.tr(
                    'อ่านสลิปอัตโนมัติจากอัลบั้ม ไม่จำกัดจำนวนรูป',
                    'Batch OCR from gallery with unlimited slip quotas',
                  ),
                  isDark: isDark,
                ),
                const SizedBox(height: 10),
                _FeatureRow(
                  icon: Icons.bar_chart_rounded,
                  iconColor: const Color(0xFF3B82F6),
                  title: context.tr(
                    'แดชบอร์ดเปรียบเทียบ 12 เดือนเต็ม',
                    'Full 12-Month Panoramic Trends',
                  ),
                  subtitle: context.tr(
                    'ดูข้อมูลย้อนหลังไม่จำกัด พร้อมวิเคราะห์แยกหมวดหมู่ลึก',
                    'Historical comparison, burn rate, and deep category breakdown',
                  ),
                  isDark: isDark,
                ),
                const SizedBox(height: 10),
                _FeatureRow(
                  icon: Icons.savings_rounded,
                  iconColor: const Color(0xFF8B5CF6),
                  title: context.tr(
                    'สร้างกระปุกออมเงิน Dreams ไม่จำกัด',
                    'Unlimited Savings Dreams',
                  ),
                  subtitle: context.tr(
                    'ตั้งเป้าหมายทุกความฝัน พร้อมระบบคำนวณเงินออมอัตโนมัติ',
                    'Track multiple goals, vacations, and emergency funds',
                  ),
                  isDark: isDark,
                ),
                const SizedBox(height: 10),
                _FeatureRow(
                  icon: Icons.file_download_rounded,
                  iconColor: const Color(0xFFEC4899),
                  title: context.tr(
                    'ส่งออกข้อมูลรายงาน (CSV / Excel)',
                    'Export Financial Reports',
                  ),
                  subtitle: context.tr(
                    'สรุปบัญชีพร้อมยื่นภาษีและวิเคราะห์ต่อได้ทันที',
                    'Export clean reports for tax filing and personal accounting',
                  ),
                  isDark: isDark,
                ),
                const SizedBox(height: 10),
                _FeatureRow(
                  icon: Icons.palette_rounded,
                  iconColor: const Color(0xFFF59E0B),
                  title: context.tr(
                    'ปลดล็อกทุกธีมพรีเมียม & ป้าย PRO',
                    'All Premium Themes & Pro Badge',
                  ),
                  subtitle: context.tr(
                    'ธีม Cyberpunk, Luxury, Sakura และสีสันพิเศษเฉพาะคุณ',
                    'Customize app aesthetic with exclusive luxury themes',
                  ),
                  isDark: isDark,
                ),
                const SizedBox(height: 24),

                // Pricing Plan Selector (Yearly vs Monthly)
                Text(
                  context.tr('เลือกแพ็กเกจที่เหมาะกับคุณ', 'Choose your plan'),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 10),

                // Plan 1: Yearly (Recommended)
                _PlanCard(
                  isSelected: _isYearly,
                  badgeText: context.tr('🔥 คุ้มค่าที่สุด • ประหยัด 17%', 'Best Value • Save 17%'),
                  title: context.tr('รายปี (Yearly Plan)', 'Yearly Plan'),
                  price: '฿350',
                  period: context.tr('/ ปี', '/ year'),
                  subPrice: context.tr('เฉลี่ยเพียง ฿29.17 / เดือน (ได้ฟรี 2 เดือน)', 'Just ~฿29 / month (2 months free)'),
                  isDark: isDark,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _isYearly = true);
                  },
                ),
                const SizedBox(height: 10),

                // Plan 2: Monthly
                _PlanCard(
                  isSelected: !_isYearly,
                  badgeText: null,
                  title: context.tr('รายเดือน (Monthly Plan)', 'Monthly Plan'),
                  price: '฿35',
                  period: context.tr('/ เดือน', '/ month'),
                  subPrice: context.tr('ยกเลิกได้ตลอดเวลา ไม่มีข้อผูกมัด', 'Cancel anytime with zero commitments'),
                  isDark: isDark,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _isYearly = false);
                  },
                ),
                const SizedBox(height: 18),

                // Error message if any
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF43F5E).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFF43F5E).withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(fontSize: 11, color: Color(0xFFF43F5E), fontWeight: FontWeight.w600),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),

                // Primary CTA Purchase Button
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handlePurchase,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.bolt_rounded, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                _isYearly
                                    ? context.tr('สมัครสมาชิกรายปี ฿350 / ปี', 'Subscribe Yearly ฿350')
                                    : context.tr('สมัครสมาชิกรายเดือน ฿35 / เดือน', 'Subscribe Monthly ฿35'),
                                style: const TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 14),

                // Restore Purchases & Legal Links (Required by Apple Review)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: _isLoading ? null : _handleRestore,
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        foregroundColor: const Color(0xFF64748B),
                      ),
                      child: Text(
                        context.tr('กู้คืนการซื้อ (Restore)', 'Restore Purchases'),
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                    ),
                    const Text(' • ', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                    TextButton(
                      onPressed: () => _openUrl('https://saveforapp.com/terms'),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        foregroundColor: const Color(0xFF64748B),
                      ),
                      child: Text(
                        context.tr('ข้อกำหนดการใช้งาน', 'Terms'),
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                      ),
                    ),
                    const Text(' • ', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                    TextButton(
                      onPressed: () => _openUrl('https://saveforapp.com/privacy'),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        foregroundColor: const Color(0xFF64748B),
                      ),
                      child: Text(
                        context.tr('นโยบายความเป็นส่วนตัว', 'Privacy'),
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Center(
                  child: Text(
                    context.tr(
                      'การสมัครจะต่ออายุอัตโนมัติ สามารถยกเลิกได้ตลอดเวลาในการตั้งค่า Apple ID / Play Store',
                      'Subscription auto-renews. Cancel anytime in Apple ID / Google Play settings.',
                    ),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 9.5,
                      color: Color(0xFF94A3B8),
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool isDark;

  const _FeatureRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B).withValues(alpha: 0.6) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155).withValues(alpha: 0.6) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 19),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final bool isSelected;
  final String? badgeText;
  final String title;
  final String price;
  final String period;
  final String subPrice;
  final bool isDark;
  final VoidCallback onTap;

  const _PlanCard({
    required this.isSelected,
    required this.badgeText,
    required this.title,
    required this.price,
    required this.period,
    required this.subPrice,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = AppTheme.primaryColor;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isSelected
                ? activeColor.withValues(alpha: isDark ? 0.18 : 0.08)
                : (isDark ? const Color(0xFF1E293B) : Colors.white),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isSelected ? activeColor : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              width: isSelected ? 2 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: activeColor.withValues(alpha: 0.15),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (badgeText != null) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    badgeText!,
                    style: const TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
              Row(
                children: [
                  // Radio indicator
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? activeColor : const Color(0xFF94A3B8),
                        width: isSelected ? 6 : 2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          subPrice,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: isSelected ? activeColor : const Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        price,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: isSelected ? activeColor : (isDark ? Colors.white : const Color(0xFF0F172A)),
                        ),
                      ),
                      Text(
                        period,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
