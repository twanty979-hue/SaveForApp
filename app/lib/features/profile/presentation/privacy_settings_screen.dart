import 'dart:convert';
import 'package:app/core/localization/app_material.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/floating_background.dart';
import '../../../core/settings/app_settings.dart';

class PrivacySettingsScreen extends StatefulWidget {
  const PrivacySettingsScreen({super.key});

  @override
  State<PrivacySettingsScreen> createState() => _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends State<PrivacySettingsScreen> {
  final ApiClient _apiClient = ApiClient();

  Future<void> _showChangePasswordModal() async {
    final currentController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();
    var obscureCurrent = true;
    var obscureNew = true;
    var saving = false;
    String? errorText;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              14,
              20,
              MediaQuery.viewInsetsOf(context).bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Text(
                    context.tr('เปลี่ยนรหัสผ่าน', 'Change password'),
                    style: TextStyle(
                      color: context.primaryTextColor,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    context.tr(
                      'ยืนยันด้วยรหัสผ่านเดิมก่อนตั้งรหัสผ่านใหม่',
                      'Confirm your current password before setting a new one.',
                    ),
                    style: TextStyle(color: context.secondaryTextColor),
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: currentController,
                    obscureText: obscureCurrent,
                    autofillHints: const [AutofillHints.password],
                    decoration: InputDecoration(
                      labelText: context.tr('รหัสผ่านเดิม', 'Current password'),
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      suffixIcon: IconButton(
                        onPressed: () => setSheetState(
                          () => obscureCurrent = !obscureCurrent,
                        ),
                        icon: Icon(
                          obscureCurrent
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: newController,
                    obscureText: obscureNew,
                    autofillHints: const [AutofillHints.newPassword],
                    decoration: InputDecoration(
                      labelText: context.tr('รหัสผ่านใหม่', 'New password'),
                      helperText: context.tr(
                        'อย่างน้อย 8 ตัวอักษร',
                        'At least 8 characters',
                      ),
                      prefixIcon: const Icon(Icons.password_rounded),
                      suffixIcon: IconButton(
                        onPressed: () =>
                            setSheetState(() => obscureNew = !obscureNew),
                        icon: Icon(
                          obscureNew
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: confirmController,
                    obscureText: true,
                    autofillHints: const [AutofillHints.newPassword],
                    decoration: InputDecoration(
                      labelText: context.tr(
                        'ยืนยันรหัสผ่านใหม่',
                        'Confirm new password',
                      ),
                      prefixIcon: const Icon(Icons.verified_user_outlined),
                    ),
                  ),
                  if (errorText != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      errorText!,
                      style: const TextStyle(color: Color(0xFFEF4444)),
                    ),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: FilledButton(
                      onPressed: saving
                          ? null
                          : () async {
                              final current = currentController.text;
                              final next = newController.text;
                              if (current.isEmpty || next.length < 8) {
                                setSheetState(
                                  () => errorText = context.tr(
                                    'กรอกรหัสเดิมและรหัสใหม่อย่างน้อย 8 ตัวอักษร',
                                    'Enter the current password and a new password of at least 8 characters.',
                                  ),
                                );
                                return;
                              }
                              if (next != confirmController.text) {
                                setSheetState(
                                  () => errorText = context.tr(
                                    'ยืนยันรหัสผ่านใหม่ไม่ตรงกัน',
                                    'New password confirmation does not match.',
                                  ),
                                );
                                return;
                              }
                              setSheetState(() {
                                saving = true;
                                errorText = null;
                              });
                              try {
                                final response = await _apiClient.post(
                                  '/auth/change-password',
                                  body: {
                                    'current_password': current,
                                    'new_password': next,
                                  },
                                );
                                if (!mounted || !sheetContext.mounted) return;
                                if (response.statusCode == 200) {
                                  if (sheetContext.mounted) {
                                    Navigator.pop(sheetContext);
                                  }
                                  if (mounted) {
                                    ScaffoldMessenger.of(
                                      this.context,
                                    ).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          this.context.tr(
                                            'เปลี่ยนรหัสผ่านเรียบร้อยแล้ว',
                                            'Password changed successfully.',
                                          ),
                                        ),
                                      ),
                                    );
                                  }
                                  return;
                                }
                                var message = context.tr(
                                  'ไม่สามารถเปลี่ยนรหัสผ่านได้',
                                  'Unable to change the password.',
                                );
                                try {
                                  final data = jsonDecode(response.body);
                                  final apiMessage = data['error']?.toString();
                                  if (apiMessage ==
                                      'The current password is incorrect') {
                                    message = context.tr(
                                      'รหัสผ่านเดิมไม่ถูกต้อง',
                                      apiMessage!,
                                    );
                                  }
                                } catch (_) {}
                                setSheetState(() => errorText = message);
                              } catch (_) {
                                if (!mounted || !sheetContext.mounted) return;
                                setSheetState(
                                  () => errorText = context.tr(
                                    'เชื่อมต่อเซิร์ฟเวอร์ไม่ได้ กรุณาลองใหม่',
                                    'Cannot reach the server. Please try again.',
                                  ),
                                );
                              } finally {
                                if (sheetContext.mounted) {
                                  setSheetState(() => saving = false);
                                }
                              }
                            },
                      child: saving
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              context.tr('เปลี่ยนรหัสผ่าน', 'Change password'),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  
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
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              children: [
                _SectionLabel(context.tr('ความปลอดภัย', 'Security')),
                const SizedBox(height: 8),
                _SettingsTile(
                  icon: Icons.password_rounded,
                  title: context.tr('เปลี่ยนรหัสผ่าน', 'Change password'),
                  subtitle: context.tr(
                    'ตั้งรหัสผ่านใหม่เพื่อความปลอดภัยของบัญชี',
                    'Set a new password for account security',
                  ),
                  onTap: _showChangePasswordModal,
                ),
                _SettingsTile(
                  icon: Icons.security_rounded,
                  title: context.tr('การยืนยันตัวตน 2 ขั้นตอน (2FA)', 'Two-Factor Auth (2FA)'),
                  subtitle: context.tr(
                    'เพิ่มความปลอดภัยด้วยรหัสผ่านชั้นที่สอง',
                    'Enhance security with 2nd step verification',
                  ),
                  onTap: () => _showMockDialog(context.tr('การยืนยันตัวตน 2 ขั้นตอน', 'Two-Factor Auth')),
                ),
                _SettingsTile(
                  icon: Icons.person_off_rounded,
                  title: context.tr('การมองเห็นโปรไฟล์', 'Profile Visibility'),
                  subtitle: context.tr(
                    'ตั้งค่าความเป็นส่วนตัวของบัญชี',
                    'Set your account privacy',
                  ),
                  onTap: () => _showMockDialog(context.tr('การมองเห็นโปรไฟล์', 'Profile Visibility')),
                ),
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
                _SettingsTile(
                  icon: Icons.devices_rounded,
                  title: context.tr('อุปกรณ์ที่เข้าสู่ระบบ', 'Active Sessions'),
                  subtitle: context.tr(
                    'จัดการอุปกรณ์ที่ล็อกอินค้างไว้',
                    'Manage active devices',
                  ),
                  onTap: () => _showMockDialog(context.tr('อุปกรณ์ที่เข้าสู่ระบบ', 'Active Sessions')),
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
                  onTap: () => _showMockDialog(context.tr('นโยบายความเป็นส่วนตัว', 'Privacy Policy')),
                ),
                _SettingsTile(
                  icon: Icons.description_rounded,
                  title: context.tr('ข้อตกลงการใช้งาน', 'Terms of Service'),
                  subtitle: context.tr(
                    'ข้อกำหนดและเงื่อนไขการใช้แอป',
                    'Terms and conditions of app usage',
                  ),
                  onTap: () => _showMockDialog(context.tr('ข้อตกลงการใช้งาน', 'Terms of Service')),
                ),
                _SettingsTile(
                  icon: Icons.download_rounded,
                  title: context.tr('ดาวน์โหลดข้อมูลส่วนตัว', 'Download My Data'),
                  subtitle: context.tr(
                    'ขอรับสำเนาข้อมูลของคุณทั้งหมด',
                    'Request a copy of all your data',
                  ),
                  onTap: () => _showMockDialog(context.tr('ดาวน์โหลดข้อมูลส่วนตัว', 'Download My Data')),
                ),
                _SettingsTile(
                  icon: Icons.location_on_rounded,
                  title: context.tr('การเข้าถึงตำแหน่งที่ตั้ง', 'Location Data'),
                  subtitle: context.tr(
                    'จัดการสิทธิ์การใช้ข้อมูลตำแหน่งที่ตั้ง',
                    'Manage location data permissions',
                  ),
                  onTap: () => _showMockDialog(context.tr('การเข้าถึงตำแหน่งที่ตั้ง', 'Location Data')),
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
                  onTap: () => _showMockDialog(context.tr('ลบบัญชี', 'Delete Account')),
                ),
              ],
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
                  ? const Color(0xFFFFF7F7)
                  : Colors.white.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: danger
                    ? const Color(0xFFFECACA)
                    : const Color(0xFFE2E8F0),
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
                              : const Color(0xFF1E293B),
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
                          style: const TextStyle(
                            color: Color(0xFF64748B),
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
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: danger
                        ? const Color(0xFFFCA5A5)
                        : const Color(0xFF94A3B8),
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
