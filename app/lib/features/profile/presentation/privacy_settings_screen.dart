import 'package:app/core/localization/app_material.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/floating_background.dart';
import '../../../core/widgets/responsive_layout.dart';
import '../../../core/settings/app_settings.dart';
import '../../auth/domain/auth_session.dart';
import '../../auth/presentation/auth_screen.dart';

class PrivacySettingsScreen extends StatefulWidget {
  const PrivacySettingsScreen({super.key});

  @override
  State<PrivacySettingsScreen> createState() => _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends State<PrivacySettingsScreen> {
  final ApiClient _apiClient = ApiClient();



  
  void _showPrivacyPolicy() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          context.tr('นโยบายความเป็นส่วนตัว', 'Privacy Policy'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Text(
            context.tr(
              'เราให้ความสำคัญกับความเป็นส่วนตัวของคุณ ข้อมูลการเงินและธุรกรรมทั้งหมดจะถูกบันทึกและจัดเก็บไว้บนอุปกรณ์ของคุณ รวมถึงซิงค์ผ่านฐานข้อมูลคลาวด์ที่ปลอดภัยเมื่อมีการเข้าสู่ระบบ เราจะไม่แบ่งปันหรือเผยแพร่ข้อมูลของคุณให้แก่บุคคลภายนอกโดยเด็ดขาด',
              'We value your privacy. All financial data and transactions are stored locally on your device and synchronized via a secure cloud database when signed in. We never share or sell your personal data to any third party.',
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.tr('ตกลง', 'OK')),
          ),
        ],
      ),
    );
  }

  void _showTermsOfService() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          context.tr('ข้อตกลงการใช้งาน', 'Terms of Service'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Text(
            context.tr(
              'แอปพลิเคชัน SaveFor เป็นเครื่องมือเพื่อช่วยในการจัดการและวางแผนการเงินส่วนบุคคล การตัดสินใจทางการเงินใด ๆ ที่เกิดขึ้นเป็นความรับผิดชอบของผู้ใช้ทั้งสิ้น เราพยายามดูแลระบบและให้บริการอย่างต่อเนื่องและปลอดภัยที่สุดเท่าที่จะทำได้',
              'SaveFor is a tool designed to assist with personal financial planning and management. Any financial decisions made remain the sole responsibility of the user. We strive to maintain continuous service and keep your data safe.',
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.tr('ตกลง', 'OK')),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          context.tr('ลบบัญชีผู้ใช้?', 'Delete Account?'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          context.tr(
            'ข้อมูลทั้งหมด รวมถึงธุรกรรม เป้าหมายความฝัน และการตั้งค่าต่าง ๆ จะถูกลบอย่างถาวรและไม่สามารถเรียกคืนได้ คุณต้องการดำเนินการต่อหรือไม่?',
            'All your data, including transactions, dreams, and settings, will be permanently deleted and cannot be recovered. Do you wish to proceed?',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.tr('ยกเลิก', 'Cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.tr('ลบบัญชี', 'Delete Account')),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    // Show loading
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      final userId = AuthSession.userId;
      if (userId != null) {
        // Cascade delete user data
        await _apiClient.delete('/transactions?user_id=eq.$userId');
        await _apiClient.delete('/dreams?user_id=eq.$userId');
        await _apiClient.delete('/recurring/expenses?user_id=eq.$userId');
        await _apiClient.delete('/recurring/sources?user_id=eq.$userId');
        await _apiClient.delete('/users?id=eq.$userId');
      }
    } catch (_) {}

    // Dismiss loading and logout
    if (mounted) {
      Navigator.pop(context); // Dismiss loading spinner
      await AuthSession.logout();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const AuthScreen()),
        (_) => false,
      );
    }
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.pageColor,
      appBar: AppBar(
        title: Text(context.tr('ความเป็นส่วนตัว', 'Privacy')),
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
                _SectionLabel(context.tr('ความปลอดภัย', 'Security')),
                const SizedBox(height: 8),

                _SettingsTile(
                  icon: Icons.fingerprint_rounded,
                  title: context.tr('ล็อกแอปก่อนเข้าใช้งาน', 'App Lock'),
                  subtitle: context.tr(
                    'ใช้รหัส PIN หรือสแกนใบหน้า',
                    'Use PIN or Face ID',
                  ),
                  trailing: Switch(
                    value: AppSettings.appLockEnabled,
                    activeThumbColor: AppTheme.primaryColor,
                    onChanged: (val) async {
                      await AppSettings.setAppLockEnabled(val);
                      if (mounted) setState(() {});
                    },
                  ),
                  onTap: () async {
                    await AppSettings.setAppLockEnabled(!AppSettings.appLockEnabled);
                    if (mounted) setState(() {});
                  },
                ),
                _SettingsTile(
                  icon: Icons.visibility_off_rounded,
                  title: context.tr('ซ่อนยอดเงินในหน้าแรก', 'Hide Balances'),
                  subtitle: context.tr(
                    'เบลอยอดเงินอัตโนมัติ',
                    'Automatically blur balances',
                  ),
                  trailing: Switch(
                    value: AppSettings.hideBalances.value,
                    activeThumbColor: AppTheme.primaryColor,
                    onChanged: (val) async {
                      await AppSettings.setHideBalances(val);
                      if (mounted) setState(() {});
                    },
                  ),
                  onTap: () async {
                    await AppSettings.setHideBalances(!AppSettings.hideBalances.value);
                    if (mounted) setState(() {});
                  },
                ),
                const SizedBox(height: 16),
                _SectionLabel(context.tr('ข้อมูลและข้อตกลง', 'Data & Agreements')),
                const SizedBox(height: 8),
                _SettingsTile(
                  icon: Icons.policy_rounded,
                  title: context.tr('นโยบายความเป็นส่วนตัว', 'Privacy Policy'),
                  subtitle: context.tr(
                    'อ่านรายละเอียดการจัดการข้อมูลส่วนบุคคล',
                    'Read details about personal data management',
                  ),
                  onTap: _showPrivacyPolicy,
                ),
                _SettingsTile(
                  icon: Icons.description_rounded,
                  title: context.tr('ข้อตกลงการใช้งาน', 'Terms of Service'),
                  subtitle: context.tr(
                    'ข้อกำหนดและเงื่อนไขการใช้แอป',
                    'Terms and conditions of app usage',
                  ),
                  onTap: _showTermsOfService,
                ),
                _SettingsTile(
                  icon: Icons.analytics_rounded,
                  title: context.tr('การเก็บข้อมูลพฤติกรรม', 'Analytics Consent'),
                  subtitle: context.tr(
                    'ช่วยเราพัฒนาแอปให้ดีขึ้น',
                    'Help us improve the app',
                  ),
                  trailing: Switch(
                    value: AppSettings.analyticsEnabled,
                    activeThumbColor: AppTheme.primaryColor,
                    onChanged: (val) async {
                      await AppSettings.setAnalyticsEnabled(val);
                      if (mounted) setState(() {});
                    },
                  ),
                  onTap: () async {
                    await AppSettings.setAnalyticsEnabled(!AppSettings.analyticsEnabled);
                    if (mounted) setState(() {});
                  },
                ),
                const SizedBox(height: 16),
                _SectionLabel(context.tr('เขตอันตราย', 'Danger Zone')),
                const SizedBox(height: 8),
                _SettingsTile(
                  icon: Icons.delete_forever_rounded,
                  title: context.tr('ลบบัญชี', 'Delete Account'),
                  subtitle: context.tr(
                    'ลบข้อมูลทั้งหมดอย่างถาวร',
                    'Permanently delete all data',
                  ),
                  danger: true,
                  onTap: _confirmDeleteAccount,
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
