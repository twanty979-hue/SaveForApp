import 'package:app/core/localization/app_material.dart';
import 'package:app/core/settings/app_settings.dart';
import 'package:google_fonts/google_fonts.dart';

class ThemePalette {
  final Color primary;
  final Color strong;
  final Color secondary;
  final Color secondaryDark;
  final Color backgroundLight;
  final Color backgroundDark;
  final Color cardLight;
  final Color cardDark;

  const ThemePalette({
    required this.primary,
    required this.strong,
    required this.secondary,
    required this.secondaryDark,
    required this.backgroundLight,
    required this.backgroundDark,
    required this.cardLight,
    required this.cardDark,
  });
}

class AppTheme {
  static const Color highlightColor = Color(0xFFF5B731);

  static ThemePalette paletteFor(ThemeStyle style) {
    switch (style) {
      case ThemeStyle.emerald:
        return const ThemePalette(
          // SaveFor brand palette: cute organic notebook & piggy bank logo
          primary: Color(0xFF7EA459), // Fresh leafy green extracted directly from logo_blue.png
          strong: Color(0xFF5A8238),  // Rich organic green from logo
          secondary: Color(0xFFE2EFCF), // Soft meadow pastel from logo
          secondaryDark: Color(0xFF2E451C),
          backgroundLight: Color(0xFFFAF7E8), // Warm paper cream from logo
          backgroundDark: Color(0xFF141910),
          cardLight: Colors.white,
          cardDark: Color(0xFF1C2417),
        );
      case ThemeStyle.cartoon:
        return const ThemePalette(
          primary: Color(0xFFD9652B),
          strong: Color(0xFFA8431B),
          secondary: Color(0xFFFFE8DB),
          secondaryDark: Color(0xFF482719),
          backgroundLight: Color(0xFFFFF9F5),
          backgroundDark: Color(0xFF25130B),
          cardLight: Colors.white,
          cardDark: Color(0xFF3A2117),
        );
      case ThemeStyle.sakura:
        return const ThemePalette(
          primary: Color(0xFFD85D84),
          strong: Color(0xFFA83B61),
          secondary: Color(0xFFFFE5EE),
          secondaryDark: Color(0xFF49232F),
          backgroundLight: Color(0xFFFFF8FA),
          backgroundDark: Color(0xFF241018),
          cardLight: Colors.white,
          cardDark: Color(0xFF381D27),
        );
      case ThemeStyle.cyberpunk:
        return const ThemePalette(
          primary: Color(0xFF8B5CF6),
          strong: Color(0xFF6D28D9),
          secondary: Color(0xFFEDE9FE),
          secondaryDark: Color(0xFF2A1B4D),
          backgroundLight: Color(0xFFFAF9FF),
          backgroundDark: Color(0xFF0D0818),
          cardLight: Colors.white,
          cardDark: Color(0xFF171024),
        );
      case ThemeStyle.luxury:
        return const ThemePalette(
          primary: Color(0xFFB88A22),
          strong: Color(0xFF8A6419),
          secondary: Color(0xFFF6E7B5),
          secondaryDark: Color(0xFF443719),
          backgroundLight: Color(0xFFFCFBF7),
          backgroundDark: Color(0xFF101018),
          cardLight: Colors.white,
          cardDark: Color(0xFF181821),
        );
    }
  }

  static ThemePalette get currentPalette =>
      paletteFor(AppSettings.themeStyle.value);
  static Color get primaryColor => currentPalette.primary;
  static Color get strongColor => currentPalette.strong;
  static Color get secondaryColor => currentPalette.secondary;
  static Color get backgroundLight => currentPalette.backgroundLight;
  static Color get backgroundDark => currentPalette.backgroundDark;
  static Color get cardLight => currentPalette.cardLight;
  static Color get cardDark => currentPalette.cardDark;

  static ThemeData get lightTheme =>
      getTheme(AppSettings.themeStyle.value, ThemeMode.light);
  static ThemeData get darkTheme =>
      getTheme(AppSettings.themeStyle.value, ThemeMode.dark);

  static ThemeData getTheme(ThemeStyle style, ThemeMode mode) {
    final isDark = mode == ThemeMode.dark;
    final brightness = isDark ? Brightness.dark : Brightness.light;
    final palette = paletteFor(style);
    final primary = palette.primary;
    final secondary = isDark ? palette.secondaryDark : palette.secondary;
    final background = isDark
        ? palette.backgroundDark
        : palette.backgroundLight;
    final card = isDark ? palette.cardDark : palette.cardLight;
    final fontFamily = _fontFamily(style);
    final borderRadius = _borderRadius(style);
    final borderColor = isDark
        ? Color.alphaBlend(primary.withValues(alpha: 0.18), card)
        : Color.alphaBlend(
            primary.withValues(alpha: 0.12),
            const Color(0xFFE2E8F0),
          );
    final onSurface = isDark ? Colors.white : const Color(0xFF172033);
    final mutedText = isDark
        ? const Color(0xFF9AA8B8)
        : const Color(0xFF667085);

    final scheme =
        ColorScheme.fromSeed(
          seedColor: primary,
          brightness: brightness,
        ).copyWith(
          primary: primary,
          onPrimary: Colors.white,
          primaryContainer: isDark ? palette.secondaryDark : palette.secondary,
          onPrimaryContainer: isDark ? Colors.white : palette.strong,
          secondary: secondary,
          onSecondary: isDark ? Colors.white : palette.strong,
          surface: card,
          surfaceContainerLowest: background,
          surfaceContainerLow: card,
          surfaceContainer: card,
          surfaceContainerHighest: isDark
              ? Color.alphaBlend(primary.withValues(alpha: 0.12), card)
              : Color.alphaBlend(primary.withValues(alpha: 0.06), card),
          onSurface: onSurface,
          onSurfaceVariant: mutedText,
          outline: borderColor,
          outlineVariant: borderColor.withValues(alpha: 0.72),
        );

    final borderSide = BorderSide(color: borderColor, width: 1);
    final activeBorderSide = BorderSide(color: primary, width: 1.7);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: fontFamily,
      colorScheme: scheme,
      primaryColor: primary,
      scaffoldBackgroundColor: background,
      canvasColor: background,
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          side: borderSide,
          borderRadius: borderRadius,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w800,
          fontFamily: fontFamily,
        ),
        iconTheme: IconThemeData(color: onSurface),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 46),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: borderRadius),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: activeBorderSide,
          minimumSize: const Size(0, 46),
          shape: RoundedRectangleBorder(borderRadius: borderRadius),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          shape: RoundedRectangleBorder(borderRadius: borderRadius),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: primary),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      dividerTheme: DividerThemeData(
        color: borderColor,
        thickness: 1,
        space: 1,
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
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: borderRadius,
          side: borderSide,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark
            ? Color.alphaBlend(primary.withValues(alpha: 0.06), card)
            : Color.alphaBlend(primary.withValues(alpha: 0.025), background),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
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
        labelStyle: TextStyle(color: mutedText),
        floatingLabelStyle: TextStyle(
          color: primary,
          fontWeight: FontWeight.w700,
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

  static String? _fontFamily(ThemeStyle style) {
    switch (style) {
      case ThemeStyle.emerald:
        return GoogleFonts.notoSansThai().fontFamily;
      case ThemeStyle.cartoon:
        return GoogleFonts.itim().fontFamily;
      case ThemeStyle.sakura:
        return GoogleFonts.mitr().fontFamily;
      case ThemeStyle.cyberpunk:
        return GoogleFonts.spaceGrotesk().fontFamily;
      case ThemeStyle.luxury:
        return GoogleFonts.notoSansThai().fontFamily;
    }
  }

  static BorderRadius _borderRadius(ThemeStyle style) {
    switch (style) {
      case ThemeStyle.cartoon:
        return BorderRadius.circular(20);
      case ThemeStyle.sakura:
        return BorderRadius.circular(22);
      case ThemeStyle.cyberpunk:
        return BorderRadius.circular(14);
      case ThemeStyle.emerald:
      case ThemeStyle.luxury:
        return BorderRadius.circular(16);
    }
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
  Color get accentColor => Theme.of(this).colorScheme.primary;
  Color get accentContainerColor => Theme.of(this).colorScheme.primaryContainer;
}
