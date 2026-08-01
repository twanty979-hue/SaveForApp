import 'package:shared_preferences/shared_preferences.dart';

class AuthSession {
  static String? userId;
  static String? displayName;
  static String? email;

  static bool get isLoggedIn => userId != null;

  // โหลดเซสชันที่เคยบันทึกไว้ในเครื่องขึ้นมาทำงาน (ถอดตัวสำรอง Hardcode ออกทั้งหมดเพื่อความปลอดภัยระดับ SaaS)
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    userId = prefs.getString('userId');
    displayName = prefs.getString('displayName');
    email = prefs.getString('email');
  }

  // เซฟเซสชันบันทึกข้อมูลลงเครื่องถาวรเมื่อยืนยันสิทธิ์สำเร็จ
  static Future<void> save(String id, String? name, String? mail) async {
    userId = id;
    displayName = name;
    email = mail;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userId', id);
    if (name != null) {
      await prefs.setString('displayName', name);
    }
    if (mail != null) {
      await prefs.setString('email', mail);
    }
  }

  // เคลียร์ประวัติล็อกอินออกจากเครื่องเมื่อผู้ใช้กดออกจากระบบ
  static Future<void> logout() async {
    userId = null;
    displayName = null;
    email = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('userId');
    await prefs.remove('displayName');
    await prefs.remove('email');
  }
}
