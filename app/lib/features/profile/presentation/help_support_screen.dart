import 'package:app/core/localization/app_material.dart';
import 'faq_screen.dart';
import 'contact_admin_screen.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/floating_background.dart';
import '../../../core/widgets/responsive_layout.dart';

class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({super.key});

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen> {
  
  void _showMockDialog(String title) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Text(context.tr('ฟีเจอร์นี้อยู่ระหว่างการพัฒนา', 'Feature in development')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.tr('ตกลง', 'OK')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.pageColor,
      appBar: AppBar(
        title: Text(context.tr('ช่วยเหลือและสนับสนุน', 'Help & Support')),
        foregroundColor: context.primaryTextColor,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: FloatingBackground()),
          SafeArea(
            top: false,
            child: ResponsiveLayout(
              maxWidth: 600,
              child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              children: [
                _SectionLabel(context.tr('ศูนย์ช่วยเหลือ', 'Help Center')),
                const SizedBox(height: 8),
                _SettingsTile(
                  icon: Icons.question_answer_rounded,
                  title: context.tr('คำถามที่พบบ่อย (FAQ)', 'FAQ'),
                  subtitle: context.tr(
                    'รวมคำตอบสำหรับปัญหาที่พบเป็นประจำ',
                    'Common questions and answers',
                  ),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const FaqScreen())),
                ),
                _SettingsTile(
                  icon: Icons.menu_book_rounded,
                  title: context.tr('คู่มือการใช้งาน', 'User Manual'),
                  subtitle: context.tr(
                    'เรียนรู้วิธีการใช้งานแอปพลิเคชัน',
                    'Learn how to use the app',
                  ),
                  onTap: () => _showMockDialog(context.tr('คู่มือการใช้งาน', 'User Manual')),
                ),
                const SizedBox(height: 16),
                _SectionLabel(context.tr('ติดต่อและรายงาน', 'Contact & Feedback')),
                const SizedBox(height: 8),
                _SettingsTile(
                  icon: Icons.support_agent_rounded,
                  title: context.tr('ติดต่อแอดมิน', 'Contact Us'),
                  subtitle: context.tr(
                    'แชทผ่าน Line, Facebook, หรือ Email',
                    'Chat via Line, Facebook, or Email',
                  ),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ContactAdminScreen())),
                ),
                _SettingsTile(
                  icon: Icons.bug_report_rounded,
                  title: context.tr('รายงานปัญหา', 'Report a Bug'),
                  subtitle: context.tr(
                    'แจ้งปัญหาการใช้งานหรือแอปพลิเคชันขัดข้อง',
                    'Report a bug or crash',
                  ),
                  onTap: () => _showMockDialog(context.tr('รายงานปัญหา', 'Report a Bug')),
                ),
                _SettingsTile(
                  icon: Icons.lightbulb_rounded,
                  title: context.tr('เสนอแนะฟีเจอร์', 'Suggest a Feature'),
                  subtitle: context.tr(
                    'บอกเราว่าคุณอยากได้ฟีเจอร์อะไรเพิ่ม',
                    'Tell us what features you want',
                  ),
                  onTap: () => _showMockDialog(context.tr('เสนอแนะฟีเจอร์', 'Suggest a Feature')),
                ),
              ],
            ),
          ),
        ),
      ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 4),
      child: Text(
        text,
        style: TextStyle(
          color: context.primaryTextColor,
          fontSize: 15,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? trailingText;
  final Widget? trailing;
  final bool danger;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.trailingText,
    this.trailing,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = danger ? const Color(0xFFEF4444) : AppTheme.primaryColor;
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 62),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: danger
                  ? (Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF271A1C)
                      : const Color(0xFFFFF7F7))
                  : context.surfaceColor,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: danger
                    ? (Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF7F1D1D)
                        : const Color(0xFFFECACA))
                    : context.borderColor,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.035),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: danger
                              ? const Color(0xFFDC2626)
                              : context.primaryTextColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: context.secondaryTextColor,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing != null)
                  trailing!
                else ...[
                  if (trailingText != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 5),
                      child: Text(
                        trailingText!,
                        style: TextStyle(
                          color: context.secondaryTextColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: danger
                        ? const Color(0xFFFCA5A5)
                        : context.secondaryTextColor,
                    size: 21,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
