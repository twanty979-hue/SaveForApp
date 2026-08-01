import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color primaryColor = Color(0xFF00A88F); 
  static const Color secondaryColor = Color(0xFFE6F4F1); 
  static const Color highlightColor = Color(0xFFF59E0B); 
  static const Color backgroundLight = Color(0xFFFAFAFA); 
  static const Color backgroundDark = Color(0xFF0F172A); 
  static const Color cardLight = Colors.white; 
  static const Color cardDark = Color(0xFF1E293B); 

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: GoogleFonts.kanit().fontFamily, // กำหนดฟอนต์ภาษาไทยสไตล์ Loopless (Kanit) ทั่วทั้งแอปพลิเคชัน
      colorScheme: const ColorScheme.light(
        primary: primaryColor,
        secondary: Color(0xFF008B75), 
        tertiary: highlightColor,
        surface: cardLight,
      ),
      scaffoldBackgroundColor: backgroundLight,
      cardTheme: const CardThemeData(
        color: cardLight,
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: Color(0xFFE2E8F0), width: 1), 
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: backgroundLight,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: Color(0xFF1E293B),
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: GoogleFonts.kanit().fontFamily, // กำหนดฟอนต์ Kanit ทั่วทั้งแอปพลิเคชันใน Dark Mode
      colorScheme: const ColorScheme.dark(
        primary: primaryColor,
        secondary: secondaryColor,
        tertiary: highlightColor,
        surface: backgroundDark,
      ),
      scaffoldBackgroundColor: backgroundDark,
      cardTheme: const CardThemeData(
        color: cardDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: backgroundDark,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
