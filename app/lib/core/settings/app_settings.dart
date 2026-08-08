import 'package:app/core/localization/app_material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ThemeStyle {
  emerald,
  cartoon,
  sakura,
  cyberpunk,
  luxury,
}

class AppSettings {
  static final ValueNotifier<ThemeMode> themeMode = ValueNotifier(
    ThemeMode.light,
  );
  static final ValueNotifier<ThemeStyle> themeStyle = ValueNotifier(
    ThemeStyle.emerald,
  );
  static final ValueNotifier<Locale> locale = ValueNotifier(const Locale('th'));

  static bool notificationsEnabled = true;
  static bool appLockEnabled = false;
  static final ValueNotifier<bool> hideBalances = ValueNotifier(false);
  static bool analyticsEnabled = true;

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    themeMode.value = _themeModeFromName(
      prefs.getString('themeMode') ?? 'light',
    );
    themeStyle.value = _themeStyleFromName(
      prefs.getString('themeStyle') ?? 'emerald',
    );
    locale.value = Locale(prefs.getString('locale') ?? 'th');
    notificationsEnabled = prefs.getBool('notificationsEnabled') ?? true;
    appLockEnabled = prefs.getBool('appLockEnabled') ?? false;
    hideBalances.value = prefs.getBool('hideBalances') ?? false;
    analyticsEnabled = prefs.getBool('analyticsEnabled') ?? true;
  }

  static Future<void> setThemeMode(ThemeMode mode) async {
    themeMode.value = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('themeMode', mode.name);
  }

  static Future<void> setThemeStyle(ThemeStyle style) async {
    themeStyle.value = style;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('themeStyle', style.name);
  }

  static Future<void> setLocale(Locale value) async {
    locale.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('locale', value.languageCode);
  }

  static Future<void> setNotificationsEnabled(bool enabled) async {
    notificationsEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notificationsEnabled', enabled);
  }

  static Future<void> setAppLockEnabled(bool enabled) async {
    appLockEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('appLockEnabled', enabled);
  }

  static Future<void> setHideBalances(bool enabled) async {
    hideBalances.value = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hideBalances', enabled);
  }

  static Future<void> setAnalyticsEnabled(bool enabled) async {
    analyticsEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('analyticsEnabled', enabled);
  }

  static ThemeMode _themeModeFromName(String value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.light;
    }
  }

  static ThemeStyle _themeStyleFromName(String value) {
    switch (value) {
      case 'emerald':
        return ThemeStyle.emerald;
      case 'cartoon':
        return ThemeStyle.cartoon;
      case 'sakura':
        return ThemeStyle.sakura;
      case 'cyberpunk':
        return ThemeStyle.cyberpunk;
      case 'luxury':
        return ThemeStyle.luxury;
      default:
        return ThemeStyle.emerald;
    }
  }
}
