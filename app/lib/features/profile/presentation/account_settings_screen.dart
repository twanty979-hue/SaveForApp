import 'dart:convert';
import 'package:app/core/localization/app_material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/network/api_client.dart';
import '../../../core/services/slip_scanner_bridge.dart';
import '../../../core/settings/app_settings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/floating_background.dart';
import '../../../core/widgets/responsive_layout.dart';
import '../../auth/domain/auth_session.dart';
import '../../auth/presentation/auth_screen.dart';
import '../../transactions/presentation/slip_scan_dialog.dart';
import '../../transactions/presentation/no_slips_found_sheet.dart';
import '../../transactions/presentation/slip_scan_date_sheet.dart';
import 'supported_banks_screen.dart';

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
  bool _autoSlipScanningEnabled = AppSettings.autoSlipScanningEnabled;
  int _slipLookbackDays = 30;
  bool _isScanningSlips = false;

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
          final dbName = profile['display_name']?.toString().trim();
          if (dbName != null && dbName.isNotEmpty) {
            _displayName = dbName;
            await AuthSession.setDisplayName(dbName);
          }
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
                style: TextStyle(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : const Color(0xFF1E293B),
                ),
                decoration: InputDecoration(
                  labelText: context.tr('ชื่อที่แสดง', 'Display name'),
                  prefixIcon: const Icon(Icons.badge_outlined),
                  filled: true,
                  fillColor: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF1E293B)
                      : const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF334155)
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
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
                                    body: {
                                      'id': userId,
                                      'display_name': value,
                                      'tier': _tier,
                                    },
                                  );

                            if (response.statusCode >= 200 &&
                                response.statusCode < 300) {
                              _profileExists = true;
                              _displayName = value;
                              await AuthSession.save(
                                userId,
                                value,
                                AuthSession.email,
                              );
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
                                    content: Text(
                                      this.context.tr(
                                        'ไม่สามารถบันทึกชื่อได้',
                                        'Could not save name',
                                      ),
                                    ),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          } catch (_) {
                            if (sheetContext.mounted) {
                              ScaffoldMessenger.of(sheetContext).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    this.context.tr(
                                      'เชื่อมต่อไม่ได้ กรุณาลองใหม่อีกครั้ง',
                                      'Cannot connect, please try again',
                                    ),
                                  ),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          } finally {
                            if (sheetContext.mounted)
                              setSheetState(() => isSaving = false);
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
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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

    if (confirmed != true || !mounted) return;

    // Show loading spinner
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final userId = AuthSession.userId;
      if (userId != null) {
        // Cascade delete all user records
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

  Future<void> _triggerManualScan() async {
    if (!SlipScannerBridge.instance.isSupported) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr(
              'ฟีเจอร์นี้รองรับบน iPhone ในเวอร์ชันนี้ครับ',
              'This feature is supported on iPhone in this version',
            ),
          ),
        ),
      );
      return;
    }

    final permission = await SlipScannerBridge.instance.requestPermission();
    if (permission == 'denied') {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr(
              'กรุณาอนุญาตการเข้าถึงรูปภาพเพื่อสแกนสลิป',
              'Please allow photo library access to scan slips',
            ),
          ),
        ),
      );
      return;
    }

    SlipScanDateSheet.show(
      context,
      onTransactionsSaved: () {
        SlipScannerBridge.instance.refreshUnscannedCount();
      },
    );
  }

  Future<void> _pickAndScanSingleSlip() async {
    if (!SlipScannerBridge.instance.isSupported) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr(
              'ฟีเจอร์นี้รองรับบน iPhone ในเวอร์ชันนี้ครับ',
              'This feature is supported on iPhone in this version',
            ),
          ),
        ),
      );
      return;
    }

    try {
      final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (picked == null) return;

      setState(() => _isScanningSlips = true);
      final slip = await SlipScannerBridge.instance.scanSingleImage(picked.path);
      if (!mounted) return;
      setState(() => _isScanningSlips = false);

      if (slip == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.tr(
                'ไม่พบข้อมูลสลิปที่รองรับในภาพนี้ (รองรับทุกธนาคารในไทย)',
                'No supported bank slip detected (supports all Thai banks)',
              ),
            ),
          ),
        );
      } else {
        SlipScanDialog.show(context, slips: [slip]);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isScanningSlips = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
      );
    }
  }

  void _chooseLookbackPeriod() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final isDark = Theme.of(sheetContext).brightness == Brightness.dark;
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                sheetContext.tr('เลือกระยะเวลาย้อนหลัง', 'Select Lookback Period'),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ListTile(
                title: Text(sheetContext.tr('ย้อนหลัง 7 วัน', 'Past 7 Days')),
                trailing: _slipLookbackDays == 7 ? Icon(Icons.check, color: AppTheme.primaryColor) : null,
                onTap: () {
                  setState(() => _slipLookbackDays = 7);
                  Navigator.pop(sheetContext);
                },
              ),
              ListTile(
                title: Text(sheetContext.tr('ย้อนหลัง 30 วัน (แนะนำ)', 'Past 30 Days (Recommended)')),
                trailing: _slipLookbackDays == 30 ? Icon(Icons.check, color: AppTheme.primaryColor) : null,
                onTap: () {
                  setState(() => _slipLookbackDays = 30);
                  Navigator.pop(sheetContext);
                },
              ),
              ListTile(
                title: Text(sheetContext.tr('ย้อนหลัง 90 วัน', 'Past 90 Days')),
                trailing: _slipLookbackDays == 90 ? Icon(Icons.check, color: AppTheme.primaryColor) : null,
                onTap: () {
                  setState(() => _slipLookbackDays = 90);
                  Navigator.pop(sheetContext);
                },
              ),
              ListTile(
                title: Text(sheetContext.tr('ทั้งหมดที่มีในเครื่อง', 'All available in device')),
                trailing: _slipLookbackDays == 0 ? Icon(Icons.check, color: AppTheme.primaryColor) : null,
                onTap: () {
                  setState(() => _slipLookbackDays = 0);
                  Navigator.pop(sheetContext);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.pageColor,
      body: Stack(
        children: [
          const Positioned.fill(child: FloatingBackground()),
          SafeArea(
            child: ResponsiveLayout(
              maxWidth: 600,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Row(
                      children: [
                        Material(
                          color: context.surfaceColor,
                          borderRadius: BorderRadius.circular(14),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () => Navigator.pop(context),
                            child: SizedBox(
                              width: 40,
                              height: 40,
                              child: Icon(
                                Icons.arrow_back_ios_new_rounded,
                                size: 18,
                                color: context.primaryTextColor,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            context.tr('ตั้งค่าบัญชี', 'Account Settings'),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: context.primaryTextColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: _isLoading
                        ? Center(
                            child: CircularProgressIndicator(
                              color: AppTheme.primaryColor,
                            ),
                          )
                        : ListView(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                            children: [
                              _SectionLabel(
                                context.tr('ข้อมูลส่วนตัว', 'Profile Information'),
                              ),
                        const SizedBox(height: 8),
                        _SettingsTile(
                          icon: Icons.badge_outlined,
                          title: context.tr('ชื่อที่แสดง', 'Display name'),
                          subtitle: _displayName.isEmpty
                              ? context.tr('ผู้ใช้งาน SaveFor', 'SaveFor User')
                              : _displayName,
                          onTap: _editDisplayName,
                        ),
                        _SettingsTile(
                          icon: Icons.alternate_email_rounded,
                          title: context.tr('อีเมล', 'Email'),
                          subtitle: _email,
                          trailing: const Icon(
                            Icons.lock_outline_rounded,
                            size: 16,
                            color: Color(0xFF94A3B8),
                          ),
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  context.tr(
                                    'ไม่สามารถเปลี่ยนอีเมลได้',
                                    'Email cannot be changed',
                                  ),
                                ),
                              ),
                            );
                          },
                        ),

                        const SizedBox(height: 22),
                        _SectionLabel(
                          context.tr('การอ่านสลิปธนาคาร (รองรับทุกธนาคารในไทย)', 'Bank Slip Scanning (All Thai Banks)'),
                        ),
                        const SizedBox(height: 8),
                        _SettingsTile(
                          icon: Icons.receipt_long_outlined,
                          title: context.tr(
                            'อ่านสลิปอัตโนมัติ',
                            'Automatic slip scanning',
                          ),
                          subtitle: context.tr(
                            'ตรวจสลิปใหม่จากอัลบั้มธนาคารในเครื่องเมื่อเปิดแอป',
                            'Check new slips from bank albums when the app opens',
                          ),
                          trailing: Switch.adaptive(
                            value: _autoSlipScanningEnabled,
                            onChanged: (value) async {
                              setState(() => _autoSlipScanningEnabled = value);
                              await AppSettings.setAutoSlipScanningEnabled(
                                value,
                              );
                            },
                          ),
                          onTap: () async {
                            final value = !_autoSlipScanningEnabled;
                            setState(() => _autoSlipScanningEnabled = value);
                            await AppSettings.setAutoSlipScanningEnabled(value);
                          },
                        ),
                        _SettingsTile(
                          icon: Icons.history_toggle_off_rounded,
                          title: context.tr('ช่วงเวลาย้อนหลัง', 'Lookback Window'),
                          subtitle: _slipLookbackDays == 0
                              ? context.tr('สแกนทั้งหมดที่มีในเครื่อง', 'All available in device')
                              : context.tr('ย้อนหลัง $_slipLookbackDays วัน', 'Past $_slipLookbackDays days'),
                          trailing: const Icon(Icons.chevron_right_rounded, size: 20, color: Color(0xFF94A3B8)),
                          onTap: _chooseLookbackPeriod,
                        ),
                        _SettingsTile(
                          icon: Icons.document_scanner_outlined,
                          title: context.tr('สแกนสลิปตอนนี้', 'Scan slips now'),
                          subtitle: context.tr('ค้นหาและนำเข้าสลิปที่ยังไม่ได้บันทึก', 'Search and import unrecorded slips'),
                          trailing: _isScanningSlips
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryColor),
                                )
                              : Icon(Icons.play_arrow_rounded, size: 22, color: AppTheme.primaryColor),
                          onTap: () {
                            if (!_isScanningSlips) _triggerManualScan();
                          },
                        ),
                        _SettingsTile(
                          icon: Icons.account_balance_rounded,
                          title: context.tr('ธนาคารที่รองรับ', 'Supported Banks'),
                          subtitle: context.tr('อ่านอัตโนมัติ 4 ธนาคารยอดนิยม', 'Auto-detect 4 popular banks'),
                          trailing: const Icon(Icons.chevron_right_rounded, size: 20, color: Color(0xFF94A3B8)),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const SupportedBanksScreen(),
                              ),
                            );
                          },
                        ),
                        _SettingsTile(
                          icon: Icons.photo_library_outlined,
                          title: context.tr('นำเข้ารูปสลิป', 'Pick a slip photo'),
                          subtitle: context.tr('เลือกรูปสลิปจากอัลบั้มเพื่อบันทึกรายการ', 'Select a slip from photos to add entry'),
                          trailing: const Icon(Icons.chevron_right_rounded, size: 20, color: Color(0xFF94A3B8)),
                          onTap: () {
                            if (!_isScanningSlips) _pickAndScanSingleSlip();
                          },
                        ),


                        const SizedBox(height: 22),
                        _SectionLabel(
                          context.tr('จัดการบัญชี', 'Account Management'),
                        ),
                        const SizedBox(height: 8),
                        _SettingsTile(
                          icon: Icons.delete_forever_rounded,
                          title: context.tr(
                            'ลบบัญชีผู้ใช้งาน',
                            'Delete Account',
                          ),
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
