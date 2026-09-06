import 'package:shared_preferences/shared_preferences.dart';

class AuthSession {
  static String? userId;
  static String? displayName;
  static String? email;
  static String? accessToken;
  static String? refreshToken;
  static String? avatarUrl;

  static bool get isLoggedIn =>
      userId?.isNotEmpty == true &&
      accessToken?.isNotEmpty == true &&
      refreshToken?.isNotEmpty == true;

  // โหลดเซสชันที่เคยบันทึกไว้ในเครื่องขึ้นมาทำงาน (ถอดตัวสำรอง Hardcode ออกทั้งหมดเพื่อความปลอดภัยระดับ SaaS)
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    userId = prefs.getString('userId');
    displayName = prefs.getString('displayName');
    email = prefs.getString('email');
    accessToken = prefs.getString('accessToken');
    refreshToken = prefs.getString('refreshToken');
    avatarUrl = prefs.getString('avatarUrl');
  }

  // เซฟเซสชันบันทึกข้อมูลลงเครื่องถาวรเมื่อยืนยันสิทธิ์สำเร็จ
  static Future<void> save(
    String id,
    String? name,
    String? mail, {
    String? token,
    String? refresh,
  }) async {
    userId = id;
    displayName = name;
    email = mail;
    if (token != null) accessToken = token;
    if (refresh != null) refreshToken = refresh;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userId', id);
    if (name != null) {
      await prefs.setString('displayName', name);
    }
    if (mail != null) {
      await prefs.setString('email', mail);
    }
    if (token != null) {
      await prefs.setString('accessToken', token);
    }
    if (refresh != null) {
      await prefs.setString('refreshToken', refresh);
    }
  }

  static Future<void> updateTokens({
    required String access,
    required String refresh,
  }) async {
    accessToken = access;
    refreshToken = refresh;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('accessToken', access);
    await prefs.setString('refreshToken', refresh);
  }

  static Future<void> setDisplayName(String? value) async {
    displayName = value;
    final prefs = await SharedPreferences.getInstance();
    if (value == null || value.isEmpty) {
      await prefs.remove('displayName');
    } else {
      await prefs.setString('displayName', value);
    }
  }

  static Future<void> setAvatarUrl(String? value) async {
    avatarUrl = value;
    final prefs = await SharedPreferences.getInstance();
    if (value == null || value.isEmpty) {
      await prefs.remove('avatarUrl');
    } else {
      await prefs.setString('avatarUrl', value);
    }
  }

  // เคลียร์ประวัติล็อกอินออกจากเครื่องเมื่อผู้ใช้กดออกจากระบบ
  static Future<void> logout() async {
    userId = null;
    displayName = null;
    email = null;
    accessToken = null;
    refreshToken = null;
    avatarUrl = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('userId');
    await prefs.remove('displayName');
    await prefs.remove('email');
    await prefs.remove('accessToken');
    await prefs.remove('refreshToken');
    await prefs.remove('avatarUrl');
  }
}
