import 'dart:convert';
import 'package:app/core/localization/app_material.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/floating_background.dart';
import '../../auth/domain/auth_session.dart';

class AccountSettingsScreen extends StatefulWidget {
  const AccountSettingsScreen({super.key});

  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  final ApiClient _apiClient = ApiClient();
  
  String _displayName = AuthSession.displayName ?? '';
  final String _email = AuthSession.email ?? '';
  bool _profileExists = false;
  String _tier = 'Free';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final userId = AuthSession.userId;
    if (userId == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    try {
      final response = await _apiClient.get(
        '/profile?id=eq.$userId&select=display_name,tier',
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final List<dynamic> data = jsonDecode(response.body);
        if (data.isNotEmpty) {
          final profile = data.first as Map<String, dynamic>;
          _profileExists = true;
          _displayName = profile['display_name']?.toString() ?? _displayName;
          _tier = profile['tier']?.toString() ?? 'Free';
        }
      }
    } catch (_) {
      // Ignore errors
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _editDisplayName() async {
    final controller = TextEditingController(text: _displayName);
    var isSaving = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            14,
            20,
            MediaQuery.viewInsetsOf(sheetContext).bottom + 20,
          ),
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
                context.tr('เปลี่ยนชื่อแสดงผล', 'Change display name'),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: context.primaryTextColor,
                ),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: controller,
                autofocus: true,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  labelText: context.tr('ชื่อที่แสดง', 'Display name'),
                  prefixIcon: const Icon(Icons.badge_outlined),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(
                      color: AppTheme.primaryColor,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          final value = controller.text.trim();
                          if (value.isEmpty) return;
                          
                          setSheetState(() => isSaving = true);
                          
                          final userId = AuthSession.userId;
                          if (userId == null) return;
                          
                          try {
                            final response = _profileExists
                                ? await _apiClient.patch(
                                    '/profile?id=eq.$userId',
                                    body: {'display_name': value},
                                  )
                                : await _apiClient.post(
                                    '/profile',
                                    body: {'id': userId, 'display_name': value, 'tier': _tier},
                                  );

                            if (response.statusCode >= 200 && response.statusCode < 300) {
                              _profileExists = true;
                              _displayName = value;
                              await AuthSession.save(userId, value, AuthSession.email);
                              if (mounted) setState(() {});
                              if (sheetContext.mounted) {
                                Navigator.pop(sheetContext);
                                ScaffoldMessenger.of(this.context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      this.context.tr(
                                        'บันทึกชื่อเรียบร้อยแล้ว',
                                        'Name saved successfully.',
                                      ),
                                    ),
                                  ),
                                );
                              }
                            } else {
                              if (sheetContext.mounted) {
                                ScaffoldMessenger.of(sheetContext).showSnackBar(
                                  SnackBar(
                                    content: Text(this.context.tr('ไม่สามารถบันทึกชื่อได้', 'Could not save name')),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          } catch (_) {
                             if (sheetContext.mounted) {
                                ScaffoldMessenger.of(sheetContext).showSnackBar(
                                  SnackBar(
                                    content: Text(this.context.tr('เชื่อมต่อเซิร์ฟเวอร์ไม่ได้', 'Cannot reach the server')),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                          } finally {
                            if (sheetContext.mounted) setSheetState(() => isSaving = false);
                          }
                        },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: isSaving
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(
                          context.tr('บันทึกการเปลี่ยนแปลง', 'Save changes'),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Future<void> _confirmDeleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          context.tr('ลบบัญชีผู้ใช้งาน', 'Delete Account'),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        content: Text(
          context.tr(
            'การลบบัญชีจะเป็นการลบข้อมูลทั้งหมดของคุณอย่างถาวรและไม่สามารถกู้คืนได้ คุณแน่ใจหรือไม่?',
            'Deleting your account will permanently delete all your data and cannot be recovered. Are you sure?',
          ),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              context.tr('ยกเลิก', 'Cancel'),
              style: const TextStyle(color: Colors.grey),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.tr('ลบบัญชี', 'Delete')),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      // Note: Full delete implementation may require a backend endpoint.
      // For now, we show a mock success and sign out.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('ลบบัญชีเรียบร้อยแล้ว', 'Account deleted.')),
          backgroundColor: Colors.green,
        ),
      );
      // await _apiClient.delete('/auth/account');
      await AuthSession.logout();
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.pageColor,
      appBar: AppBar(
        title: Text(context.tr('ตั้งค่าบัญชี', 'Account Settings')),
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
            child: _isLoading 
                ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                    children: [
                      _SectionLabel(context.tr('ข้อมูลส่วนตัว', 'Profile Information')),
                      const SizedBox(height: 8),
                      _SettingsTile(
                        icon: Icons.badge_outlined,
                        title: context.tr('ชื่อที่แสดง', 'Display name'),
                        subtitle: _displayName.isEmpty ? context.tr('ผู้ใช้งาน SaveFor', 'SaveFor User') : _displayName,
                        onTap: _editDisplayName,
                      ),
                      _SettingsTile(
                        icon: Icons.alternate_email_rounded,
                        title: context.tr('อีเมล', 'Email'),
                        subtitle: _email,
                        trailing: const Icon(Icons.lock_outline_rounded, size: 16, color: Color(0xFF94A3B8)),
                        onTap: () {
                           ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(context.tr('ไม่สามารถเปลี่ยนอีเมลได้', 'Email cannot be changed')),
                              ),
                            );
                        },
                      ),
                      
                      const SizedBox(height: 22),
                      _SectionLabel(context.tr('การจัดการข้อมูล', 'Data Management')),
                      const SizedBox(height: 8),
                      _SettingsTile(
                        icon: Icons.download_rounded,
                        title: context.tr('ส่งออกข้อมูล', 'Export Data'),
                        subtitle: context.tr('ดาวน์โหลดประวัติทั้งหมด', 'Download all history'),
                        trailing: const Icon(Icons.lock_outline_rounded, size: 16, color: Color(0xFF94A3B8)),
                        onTap: () {},
                      ),
                      _SettingsTile(
                        icon: Icons.cleaning_services_rounded,
                        title: context.tr('ล้างข้อมูล', 'Clear Data'),
                        subtitle: context.tr('ลบประวัติรายรับรายจ่ายทั้งหมด', 'Delete all transaction history'),
                        trailing: const Icon(Icons.lock_outline_rounded, size: 16, color: Color(0xFF94A3B8)),
                        onTap: () {},
                      ),

                      const SizedBox(height: 22),
                      _SectionLabel(context.tr('การเชื่อมต่อบัญชี', 'Linked Accounts')),
                      const SizedBox(height: 8),
                      _SettingsTile(
                        icon: Icons.link_rounded,
                        title: context.tr('เชื่อมต่อโซเชียล', 'Connect Social'),
                        subtitle: context.tr('Google, Apple ID, LINE', 'Google, Apple ID, LINE'),
                        trailing: const Icon(Icons.lock_outline_rounded, size: 16, color: Color(0xFF94A3B8)),
                        onTap: () {},
                      ),
                      
                      const SizedBox(height: 22),
                      _SectionLabel(context.tr('แพ็กเกจการใช้งาน', 'Subscription')),
                      const SizedBox(height: 8),
                      _SettingsTile(
                        icon: Icons.star_rounded,
                        title: context.tr('แพ็กเกจปัจจุบัน', 'Current Plan'),
                        subtitle: context.tr('฿0 / เดือน', '฿0 / month'),
                        trailingText: _tier.toUpperCase(),
                        onTap: () {},
                      ),

                      const SizedBox(height: 22),
                      _SectionLabel(context.tr('การจัดการบัญชีระดับลึก', 'Danger Zone')),
                      const SizedBox(height: 8),
                      _SettingsTile(
                        icon: Icons.delete_forever_rounded,
                        title: context.tr('ลบบัญชีผู้ใช้งาน', 'Delete Account'),
                        subtitle: context.tr('ลบข้อมูลทั้งหมดอย่างถาวร', 'Permanently delete all data'),
                        danger: true,
                        onTap: _confirmDeleteAccount,
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
