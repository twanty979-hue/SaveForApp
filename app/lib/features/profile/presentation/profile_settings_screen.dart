import 'dart:convert';

import 'package:app/core/localization/app_material.dart';
import 'package:flutter/services.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/network/api_client.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/notifications/notification_service.dart';
import '../../../core/settings/app_settings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/floating_background.dart';
import '../../../core/widgets/responsive_layout.dart';
import '../../../core/widgets/safe_network_image.dart';
import '../../auth/domain/auth_session.dart';
import '../../auth/presentation/auth_screen.dart';
import 'privacy_settings_screen.dart';
import 'account_settings_screen.dart';
import 'help_support_screen.dart';

class ProfileSettingsScreen extends StatefulWidget {
  const ProfileSettingsScreen({super.key});

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  final ApiClient _apiClient = ApiClient();

  bool _isLoading = false;
  bool _isSaving = false;
  bool _isUploadingAvatar = false;
  bool _profileExists = false;
  bool _notificationsEnabled = AppSettings.notificationsEnabled;
  String _displayName = AuthSession.displayName ?? '';
  String _tier = 'free';
  String? _avatarUrl = AuthSession.avatarUrl;

  String get _email => AuthSession.email ?? '';

  String get _initial {
    final source = _displayName.trim().isNotEmpty
        ? _displayName.trim()
        : _email.trim();
    return source.isEmpty ? 'U' : source.characters.first.toUpperCase();
  }

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
      final response = await _apiClient.get('/profile?id=eq.$userId&select=*');
      if (response.statusCode == 200) {
        final List<dynamic> profiles = jsonDecode(response.body);
        if (profiles.isNotEmpty) {
          final profile = profiles.first as Map<String, dynamic>;
          _profileExists = true;
          final dbName = profile['display_name']?.toString().trim();
          if (dbName != null && dbName.isNotEmpty) {
            _displayName = dbName;
            await AuthSession.setDisplayName(dbName);
          }
          _tier = profile['tier']?.toString() ?? 'free';
        }
      }

      final avatarResponse = await _apiClient.get('/profile/avatar');
      if (avatarResponse.statusCode == 200) {
        final avatarData = jsonDecode(avatarResponse.body);
        final avatarPath = avatarData['avatar_url']?.toString();
        _avatarUrl = avatarPath == null
            ? null
            : _apiClient.absoluteUrl(avatarPath);
        await AuthSession.setAvatarUrl(_avatarUrl);
      }
    } catch (_) {
      // ใช้ข้อมูลในเครื่องหากเครือข่ายไม่พร้อม
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showAvatarOptions() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SheetHandle(),
              const SizedBox(height: 18),
              const Text(
                'รูปโปรไฟล์',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 10),
              ListTile(
                leading: Icon(
                  Icons.photo_library_outlined,
                  color: AppTheme.primaryColor,
                ),
                title: Text(
                  context.tr('เลือกรูปจากเครื่อง', 'Choose from gallery'),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _pickAvatar(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: Icon(
                  Icons.photo_camera_outlined,
                  color: AppTheme.primaryColor,
                ),
                title: Text(context.tr('ถ่ายรูปใหม่', 'Take a new photo')),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _pickAvatar(ImageSource.camera);
                },
              ),
              if (_avatarUrl?.isNotEmpty == true)
                ListTile(
                  leading: const Icon(
                    Icons.delete_outline_rounded,
                    color: Color(0xFFEF4444),
                  ),
                  title: const Text(
                    'ลบรูปโปรไฟล์',
                    style: TextStyle(color: Color(0xFFEF4444)),
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _deleteAvatar();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickAvatar(ImageSource source) async {
    try {
      final image = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 88,
      );
      if (image == null || !mounted) return;

      final croppedImage = await ImageCropper().cropImage(
        sourcePath: image.path,
        maxWidth: 1200,
        maxHeight: 1200,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        compressFormat: ImageCompressFormat.jpg,
        compressQuality: 88,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'ครอปรูปโปรไฟล์',
            toolbarColor: AppTheme.primaryColor,
            toolbarWidgetColor: Colors.white,
            activeControlsWidgetColor: AppTheme.primaryColor,
            backgroundColor: const Color(0xFF0F172A),
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
            hideBottomControls: false,
            showCropGrid: true,
          ),
          IOSUiSettings(
            title: 'ครอปรูปโปรไฟล์',
            doneButtonTitle: 'ใช้รูปนี้',
            cancelButtonTitle: 'ยกเลิก',
            aspectRatioLockEnabled: true,
            aspectRatioPickerButtonHidden: true,
            resetAspectRatioEnabled: false,
          ),
        ],
      );
      if (croppedImage == null || !mounted) return;

      setState(() => _isUploadingAvatar = true);
      final response = await _apiClient.multipartPost(
        '/profile/avatar',
        fieldName: 'avatar',
        filename: 'profile.jpg',
        bytes: await croppedImage.readAsBytes(),
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body);
        final avatarPath = data['avatar_url']?.toString();
        final avatarUrl = avatarPath == null
            ? null
            : _apiClient.absoluteUrl(avatarPath);
        await AuthSession.setAvatarUrl(avatarUrl);
        if (mounted) {
          setState(() => _avatarUrl = avatarUrl);
          _showMessage('เปลี่ยนรูปโปรไฟล์เรียบร้อยแล้ว');
        }
      } else {
        _showMessage(_avatarError(response.body), isError: true);
      }
    } catch (_) {
      _showMessage('ไม่สามารถอัปโหลดรูปโปรไฟล์ได้', isError: true);
    } finally {
      if (mounted) setState(() => _isUploadingAvatar = false);
    }
  }

  Future<void> _deleteAvatar() async {
    setState(() => _isUploadingAvatar = true);
    try {
      final response = await _apiClient.delete('/profile/avatar');
      if (response.statusCode >= 200 && response.statusCode < 300) {
        await AuthSession.setAvatarUrl(null);
        if (mounted) {
          setState(() => _avatarUrl = null);
          _showMessage('ลบรูปโปรไฟล์แล้ว');
        }
      } else {
        _showMessage('ไม่สามารถลบรูปโปรไฟล์ได้', isError: true);
      }
    } catch (_) {
      _showMessage('ไม่สามารถเชื่อมต่อเซิร์ฟเวอร์ได้', isError: true);
    } finally {
      if (mounted) setState(() => _isUploadingAvatar = false);
    }
  }

  String _avatarError(String responseBody) {
    try {
      final data = jsonDecode(responseBody);
      final message = data['error']?.toString();
      if (message?.isNotEmpty == true) return message!;
    } catch (_) {}
    return 'ไม่สามารถอัปโหลดรูปโปรไฟล์ได้';
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? const Color(0xFFEF4444)
            : AppTheme.primaryColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _showThemeSettings() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SheetHandle(),
            const SizedBox(height: 18),
            Text(
              context.tr('ธีมของแอป', 'App theme'),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: context.primaryTextColor,
              ),
            ),
            const SizedBox(height: 10),
            for (final mode in const [ThemeMode.light, ThemeMode.dark])
              ListTile(
                title: Text(_themeName(mode)),
                leading: Icon(_themeIcon(mode)),
                trailing: AppSettings.themeMode.value == mode
                    ? Icon(Icons.check_circle, color: AppTheme.primaryColor)
                    : const Icon(
                        Icons.circle_outlined,
                        color: Color(0xFFCBD5E1),
                      ),
                onTap: () async {
                  await AppSettings.setThemeMode(mode);
                  if (mounted) setState(() {});
                  if (sheetContext.mounted) Navigator.pop(sheetContext);
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showThemeStyleSettings() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SheetHandle(),
                const SizedBox(height: 18),
                Text(
                  context.tr('เลือกสไตล์ธีม', 'Select Theme Style'),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: context.primaryTextColor,
                  ),
                ),
                const SizedBox(height: 10),
                for (final style in ThemeStyle.values)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      leading: _buildThemeAvatar(style),
                      title: Text(
                        _themeStyleName(style),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: context.primaryTextColor,
                        ),
                      ),
                      subtitle: Text(
                        _themeStyleSubtitle(style),
                        style: TextStyle(
                          fontSize: 11,
                          color: context.secondaryTextColor,
                        ),
                      ),
                      trailing: AppSettings.themeStyle.value == style
                          ? Icon(
                              Icons.check_circle,
                              color: Theme.of(context).primaryColor,
                              size: 24,
                            )
                          : Icon(
                              Icons.circle_outlined,
                              color: context.borderColor,
                              size: 24,
                            ),
                      onTap: () async {
                        await AppSettings.setThemeStyle(style);
                        if (mounted) setState(() {});
                        if (sheetContext.mounted) Navigator.pop(sheetContext);
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _themeStyleName(ThemeStyle style) {
    switch (style) {
      case ThemeStyle.emerald:
        return context.tr(
          'SaveFor แบรนด์ (น้ำเงิน-เขียวอมฟ้า)',
          'SaveFor Brand (Navy & Teal)',
        );
      case ThemeStyle.cartoon:
        return context.tr('การ์ตูนแมวส้ม 🐱', 'Orange Cat Cartoon 🐱');
      case ThemeStyle.sakura:
        return context.tr('ซากุระพาสเทล 🌸', 'Sakura Pastel 🌸');
      case ThemeStyle.cyberpunk:
        return context.tr('ไซเบอร์พังก์นีออน ⚡', 'Cyberpunk Neon ⚡');
      case ThemeStyle.luxury:
        return context.tr('ลักชัวรีสีทอง 👑', 'Luxury Gold 👑');
    }
  }

  void _showFcmTokenDialog() {
    final token = NotificationService.instance.currentToken;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.key_rounded, color: AppTheme.primaryColor),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                context.tr('FCM Device Token', 'FCM Device Token'),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              token != null
                  ? context.tr(
                      'ใช้โทเคนนี้สำหรับวางในช่อง "Send test message" บน Firebase Console เพื่อยิงทดสอบเฉพาะเครื่องนี้:',
                      'Use this token in Firebase Console "Send test message" to test targeting this device:',
                    )
                  : context.tr(
                      'ยังไม่พบ Token ในระบบ\n\n(หากรันบน iOS Simulator จะไม่รองรับ APNs ของ Apple แนะนำให้ทดสอบบน iPhone เครื่องจริง หรือเลือก Target เป็นแอป com.savefor.app บนหน้าเว็บ Firebase แทนครับ)',
                      'Token not found yet.\n\n(iOS Simulator does not support APNs. Test on a real device or target app com.savefor.app directly on Firebase).',
                    ),
              style: TextStyle(
                fontSize: 13,
                color: context.secondaryTextColor,
              ),
            ),
            if (token != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: context.borderColor),
                ),
                child: SelectableText(
                  token,
                  style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (token != null)
            FilledButton.icon(
              icon: const Icon(Icons.copy_rounded, size: 16),
              label: Text(context.tr('คัดลอก Token', 'Copy Token')),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: token));
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      context.tr(
                        'คัดลอก FCM Token เรียบร้อยแล้ว',
                        'FCM Token copied to clipboard',
                      ),
                    ),
                  ),
                );
              },
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.tr('ปิด', 'Close')),
          ),
        ],
      ),
    );
  }

  Future<void> _showLanguageSettings() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SheetHandle(),
            const SizedBox(height: 18),
            Text(
              context.tr('ภาษา', 'Language'),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: context.primaryTextColor,
              ),
            ),
            const SizedBox(height: 10),
            ListTile(
              leading: const Text('🇹🇭', style: TextStyle(fontSize: 24)),
              title: const Text('ภาษาไทย'),
              trailing: AppSettings.locale.value.languageCode == 'th'
                  ? Icon(Icons.check_circle, color: AppTheme.primaryColor)
                  : const Icon(Icons.circle_outlined),
              onTap: () async {
                await AppSettings.setLocale(const Locale('th'));
                if (mounted) setState(() {});
                if (sheetContext.mounted) Navigator.pop(sheetContext);
              },
            ),
            ListTile(
              leading: const Text('🇬🇧', style: TextStyle(fontSize: 24)),
              title: const Text('English'),
              trailing: AppSettings.locale.value.languageCode == 'en'
                  ? Icon(Icons.check_circle, color: AppTheme.primaryColor)
                  : const Icon(Icons.circle_outlined),
              onTap: () async {
                await AppSettings.setLocale(const Locale('en'));
                if (mounted) setState(() {});
                if (sheetContext.mounted) Navigator.pop(sheetContext);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showPrivacySettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const PrivacySettingsScreen()),
    );
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(context.tr('ออกจากระบบ?', 'Sign out?')),
        content: Text(
          context.tr(
            'คุณจะต้องเข้าสู่ระบบอีกครั้งเพื่อใช้งานต่อ',
            'You will need to sign in again to continue.',
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
            child: Text(context.tr('ออกจากระบบ', 'Sign out')),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    await AuthSession.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const AuthScreen()),
      (_) => false,
    );
  }

  String _themeName(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return context.tr('สว่าง', 'Light');
      case ThemeMode.dark:
        return context.tr('มืด', 'Dark');
      case ThemeMode.system:
        return context.tr('ตามระบบ', 'System');
    }
  }

  IconData _themeIcon(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return Icons.light_mode_outlined;
      case ThemeMode.dark:
        return Icons.dark_mode_outlined;
      case ThemeMode.system:
        return Icons.phone_android_outlined;
    }
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
                            context.tr('โปรไฟล์และการตั้งค่า', 'Profile & settings'),
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
                              _buildProfileHeader(),
                              const SizedBox(height: 22),
                              _SectionLabel(context.tr('การตั้งค่า', 'Settings')),
                        const SizedBox(height: 8),
                        _SettingsTile(
                          icon: Icons.manage_accounts_outlined,
                          title: context.tr('ตั้งค่าบัญชี', 'Account settings'),
                          subtitle: context.tr(
                            'ชื่อที่แสดงและข้อมูลเข้าสู่ระบบ',
                            'Display name and sign-in information',
                          ),
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const AccountSettingsScreen(),
                              ),
                            );
                            _loadProfile();
                          },
                        ),
                        _SettingsTile(
                          icon: Icons.shield_outlined,
                          title: context.tr('ความเป็นส่วนตัว', 'Privacy'),
                          subtitle: context.tr(
                            'ข้อมูลและความปลอดภัยของบัญชี',
                            'Account data and security',
                          ),
                          onTap: _showPrivacySettings,
                        ),
                        _SettingsTile(
                          icon: Icons.language_rounded,
                          title: context.tr('ภาษา', 'Language'),
                          trailingText:
                              AppSettings.locale.value.languageCode == 'en'
                              ? 'English'
                              : 'ไทย',
                          onTap: _showLanguageSettings,
                        ),
                        _SettingsTile(
                          icon: Icons.palette_outlined,
                          title: context.tr('ธีม', 'Theme'),
                          trailingText: _themeName(AppSettings.themeMode.value),
                          onTap: _showThemeSettings,
                        ),
                        _SettingsTile(
                          icon: Icons.brush_outlined,
                          title: context.tr('สไตล์ธีม', 'Theme style'),
                          trailingText: _themeStyleName(
                            AppSettings.themeStyle.value,
                          ),
                          onTap: _showThemeStyleSettings,
                        ),
                        _SettingsTile(
                          icon: Icons.notifications_none_rounded,
                          title: context.tr('การแจ้งเตือน', 'Notifications'),
                          subtitle: context.tr(
                            'เตือนรายการและเป้าหมายที่กำหนดไว้',
                            'Reminders for scheduled items and goals',
                          ),
                          trailing: Switch.adaptive(
                            value: _notificationsEnabled,
                            activeTrackColor: AppTheme.primaryColor,
                            onChanged: (value) async {
                              setState(() => _notificationsEnabled = value);
                              await AppSettings.setNotificationsEnabled(value);
                              await NotificationService.instance.setEnabled(
                                value,
                              );
                            },
                          ),
                          onTap: () async {
                            final value = !_notificationsEnabled;
                            setState(() => _notificationsEnabled = value);
                            await AppSettings.setNotificationsEnabled(value);
                            await NotificationService.instance.setEnabled(
                              value,
                            );
                          },
                        ),
                        if (_notificationsEnabled)
                          _SettingsTile(
                            icon: Icons.key_rounded,
                            title: context.tr(
                              'FCM Device Token (สำหรับทดสอบยิง)',
                              'FCM Device Token (For Testing)',
                            ),
                            subtitle: context.tr(
                              'แตะเพื่อดูหรือคัดลอกรหัสโทเคนของเครื่องนี้',
                              'Tap to view or copy device token',
                            ),
                            trailing: Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 14,
                              color: context.secondaryTextColor,
                            ),
                            onTap: _showFcmTokenDialog,
                          ),
                        _SettingsTile(
                          icon: Icons.help_outline_rounded,
                          title: context.tr(
                            'ความช่วยเหลือและการสนับสนุน',
                            'Help & support',
                          ),
                          subtitle: context.tr(
                            'คำถามที่พบบ่อยและการติดต่อ',
                            'Frequently asked questions and contact',
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const HelpSupportScreen(),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 14),
                        _SettingsTile(
                          icon: Icons.logout_rounded,
                          title: context.tr('ออกจากระบบ', 'Sign out'),
                          danger: true,
                          onTap: _confirmLogout,
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

  Widget _buildProfileHeader() {
    final isPro = _tier.toLowerCase() == 'pro';
    final palette = AppTheme.currentPalette;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [palette.primary, palette.strong],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.22),
            blurRadius: 22,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: _isUploadingAvatar ? null : _showAvatarOptions,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _isUploadingAvatar
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.3,
                          ),
                        )
                      : _avatarUrl?.isNotEmpty == true
                      ? SafeNetworkImage(
                          url: _avatarUrl!,
                          width: 64,
                          height: 64,
                          fit: BoxFit.cover,
                          isCircle: true,
                          errorBuilder: (_, _, _) => _buildInitialAvatar(),
                        )
                      : _buildInitialAvatar(),
                ),
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    width: 23,
                    height: 23,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: palette.strong),
                    ),
                    child: Icon(
                      Icons.camera_alt_rounded,
                      size: 13,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _displayName.trim().isEmpty
                      ? 'ผู้ใช้งาน SaveFor'
                      : _displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.82),
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.17),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.30),
                    ),
                  ),
                  child: Text(
                    isPro ? 'SAVEFOR PRO' : 'SAVEFOR FREE',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      letterSpacing: 0.5,
                      fontWeight: FontWeight.w800,
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

  Widget _buildThemeAvatar(ThemeStyle style) {
    final palette = AppTheme.paletteFor(style);
    switch (style) {
      case ThemeStyle.emerald:
        return Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [palette.primary, palette.strong],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: palette.primary.withValues(alpha: 0.35),
              width: 1.5,
            ),
          ),
          child: const Center(
            child: Icon(
              Icons.account_balance_wallet_outlined,
              color: Colors.white,
              size: 20,
            ),
          ),
        );
      case ThemeStyle.cartoon:
        return Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: palette.secondary,
            border: Border.all(color: palette.strong, width: 1.5),
          ),
          child: ClipOval(
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(painter: _CheckeredAvatarPainter()),
                ),
                const Center(child: Text('🐾', style: TextStyle(fontSize: 16))),
              ],
            ),
          ),
        );
      case ThemeStyle.sakura:
        return Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [
                palette.secondary,
                palette.primary.withValues(alpha: 0.7),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: palette.primary.withValues(alpha: 0.3),
              width: 1.5,
            ),
          ),
          child: const Center(
            child: Text('🌸', style: TextStyle(fontSize: 16)),
          ),
        );
      case ThemeStyle.cyberpunk:
        return Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: palette.secondaryDark,
            border: Border.all(color: palette.primary, width: 1.5),
          ),
          child: ClipOval(
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(painter: _CyberAvatarPainter()),
                ),
                const Center(child: Text('⚡', style: TextStyle(fontSize: 14))),
              ],
            ),
          ),
        );
      case ThemeStyle.luxury:
        return Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [palette.strong, palette.backgroundDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: palette.primary, width: 1.5),
          ),
          child: const Center(
            child: Text('👑', style: TextStyle(fontSize: 14)),
          ),
        );
    }
  }

  String _themeStyleSubtitle(ThemeStyle style) {
    switch (style) {
      case ThemeStyle.emerald:
        return context.tr(
          'สีเขียวละมุนและครีมวอร์มโทน ตามโลโก้สมุดรายรับรายจ่ายน้องหมู',
          'Cozy sage green & warm cream palette matching app logo',
        );
      case ThemeStyle.cartoon:
        return context.tr(
          'การ์ตูนแมวส้มพาสเทล ขอบคอมมิคหนา',
          'Cozy orange cat & neobrutalism cartoon',
        );
      case ThemeStyle.sakura:
        return context.tr(
          'ซากุระพาสเทล ละมุนละไมขอบโค้งมน',
          'Soft cherry blossom pastel & round cards',
        );
      case ThemeStyle.cyberpunk:
        return context.tr(
          'นีออนสะท้อนแสง มืดนีออนสไตล์ไซไฟ',
          'Neon glow & synthwave futuristic console',
        );
      case ThemeStyle.luxury:
        return context.tr(
          'ดำหรูหรา ตัดทองคำแท้พรีเมียม',
          'Obsidian dark & premium brushed gold luxury',
        );
    }
  }

  Widget _buildInitialAvatar() {
    return Center(
      child: Text(
        _initial,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 26,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: Color(0xFF64748B),
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

class _CheckeredAvatarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFFF9233).withValues(alpha: 0.4)
      ..style = PaintingStyle.fill;
    const double step = 8.0;
    for (double x = 0; x < size.width; x += step * 2) {
      for (double y = 0; y < size.height; y += step * 2) {
        canvas.drawRect(Rect.fromLTWH(x, y, step, step), paint);
        canvas.drawRect(Rect.fromLTWH(x + step, y + step, step, step), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CyberAvatarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFFF007F).withValues(alpha: 0.4)
      ..strokeWidth = 2.0;
    canvas.drawLine(const Offset(0, 30), const Offset(30, 0), paint);
    canvas.drawLine(const Offset(10, 44), const Offset(44, 10), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 38,
        height: 4,
        decoration: BoxDecoration(
          color: const Color(0xFFCBD5E1),
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}
