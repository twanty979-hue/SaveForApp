import 'package:app/core/localization/app_material.dart';
import 'package:app/core/settings/app_settings.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color primaryColor = Color(0xFF00A88F);
  static const Color secondaryColor = Color(0xFFE6F4F1);
  static const Color highlightColor = Color(0xFFF59E0B);
  static const Color backgroundLight = Color(0xFFFAFAFA);
  static const Color backgroundDark = Color(0xFF0F172A);
  static const Color cardLight = Colors.white;
  static const Color cardDark = Color(0xFF1E293B);

  static ThemeData get lightTheme => getTheme(AppSettings.themeStyle.value, ThemeMode.light);
  static ThemeData get darkTheme => getTheme(AppSettings.themeStyle.value, ThemeMode.dark);

  static ThemeData getTheme(ThemeStyle style, ThemeMode mode) {
    final isDark = mode == ThemeMode.dark;
    final brightness = isDark ? Brightness.dark : Brightness.light;

    Color primary;
    Color secondary;
    Color highlight = const Color(0xFFF59E0B);
    Color background;
    Color card;
    String? fontFamily;
    BorderRadius borderRadius = BorderRadius.circular(16);
    BorderSide borderSide;
    BorderSide activeBorderSide;

    switch (style) {
      case ThemeStyle.emerald:
        primary = const Color(0xFF00A88F);
        secondary = const Color(0xFFE6F4F1);
        background = isDark ? const Color(0xFF0F172A) : const Color(0xFFFAFAFA);
        card = isDark ? const Color(0xFF1E293B) : Colors.white;
        fontFamily = GoogleFonts.kanit().fontFamily;
        borderSide = BorderSide(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          width: 1,
        );
        activeBorderSide = const BorderSide(color: Color(0xFF00A88F), width: 1.5);
        break;

      case ThemeStyle.cartoon:
        // Orange Cat / Playful Comic Theme
        primary = const Color(0xFFFF9233); // Orange cat orange!
        secondary = const Color(0xFFFFF3E6); // Cream orange
        background = isDark ? const Color(0xFF2B1A0E) : const Color(0xFFFFFDF5);
        card = isDark ? const Color(0xFF3D2718) : Colors.white;
        fontFamily = GoogleFonts.itim().fontFamily; // Playful handwritten font
        borderRadius = BorderRadius.circular(20);
        // Playful thick borders for Neobrutalism comic look
        borderSide = BorderSide(
          color: isDark ? const Color(0xFFFFFDF5) : const Color(0xFF2B1A0E),
          width: 2.0,
        );
        activeBorderSide = BorderSide(color: primary, width: 2.5);
        break;

      case ThemeStyle.sakura:
        // Japanese Sakura Pastel Pink
        primary = const Color(0xFFFF8FA3); // Sakura Pink
        secondary = const Color(0xFFFFF0F2);
        background = isDark ? const Color(0xFF261217) : const Color(0xFFFFF6F8);
        card = isDark ? const Color(0xFF381D23) : Colors.white;
        fontFamily = GoogleFonts.mitr().fontFamily; // Rounded & clean Mitr
        borderRadius = BorderRadius.circular(24); // Ultra rounded bubble corners
        borderSide = BorderSide(
          color: isDark ? const Color(0xFF4C2731) : const Color(0xFFFFE3E7),
          width: 1.2,
        );
        activeBorderSide = BorderSide(color: primary, width: 1.8);
        break;

      case ThemeStyle.cyberpunk:
        // Synthwave Cyberpunk Neon
        primary = const Color(0xFFFF007F); // Neon Magenta Fuchsia
        secondary = const Color(0xFF1F0D3D);
        background = isDark ? const Color(0xFF090514) : const Color(0xFFF5F3FF);
        card = isDark ? const Color(0xFF170E2B) : Colors.white;
        fontFamily = GoogleFonts.orbitron().fontFamily; // Futuristic numbers/text
        borderRadius = BorderRadius.circular(12);
        borderSide = BorderSide(
          color: isDark ? const Color(0xFF00FFF0) : const Color(0xFFFF007F), // Neon cyan in dark mode, magenta in light
          width: 1.5,
        );
        activeBorderSide = const BorderSide(color: Color(0xFF00FFF0), width: 2);
        break;

      case ThemeStyle.luxury:
        // Premium Obsidian & Gold
        primary = const Color(0xFFD4AF37); // Gold
        secondary = const Color(0xFF231C0C);
        background = isDark ? const Color(0xFF080B11) : const Color(0xFFFAF9F6);
        card = isDark ? const Color(0xFF121824) : Colors.white;
        fontFamily = GoogleFonts.notoSansThai().fontFamily; // Classic elegant Noto Sans
        borderRadius = BorderRadius.circular(16);
        borderSide = BorderSide(
          color: isDark ? const Color(0xFF4A3E20) : const Color(0xFFE5D5A1),
          width: 1.2,
        );
        activeBorderSide = BorderSide(color: primary, width: 1.8);
        break;
    }

    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: brightness,
      surface: card,
      onSurface: isDark ? Colors.white : const Color(0xFF1E293B),
      onSurfaceVariant: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: fontFamily,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: borderSide,
          borderRadius: borderRadius,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: isDark ? Colors.white : const Color(0xFF1E293B),
          fontSize: 20,
          fontWeight: FontWeight.bold,
          fontFamily: fontFamily,
        ),
      ),
      pageTransitionsTheme: _pageTransitions,
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: borderRadius.topLeft),
          side: borderSide,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: card,
        shape: RoundedRectangleBorder(
          borderRadius: borderRadius,
          side: borderSide,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? card.withValues(alpha: 0.8) : const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: borderRadius,
          borderSide: borderSide,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: borderRadius,
          borderSide: borderSide,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: borderRadius,
          borderSide: activeBorderSide,
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: borderRadius,
          side: borderSide,
        ),
      ),
    );
  }

  static const PageTransitionsTheme _pageTransitions = PageTransitionsTheme(
    builders: {
      TargetPlatform.android: ZoomPageTransitionsBuilder(
        allowEnterRouteSnapshotting: false,
      ),
      TargetPlatform.iOS: ZoomPageTransitionsBuilder(
        allowEnterRouteSnapshotting: false,
      ),
    },
  );
}

extension AppThemeContext on BuildContext {
  Color get pageColor => Theme.of(this).scaffoldBackgroundColor;
  Color get surfaceColor => Theme.of(this).colorScheme.surface;
  Color get primaryTextColor => Theme.of(this).colorScheme.onSurface;
  Color get secondaryTextColor => Theme.of(this).colorScheme.onSurfaceVariant;
  Color get borderColor => Theme.of(this).colorScheme.outlineVariant;
}
