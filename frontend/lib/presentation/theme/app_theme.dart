import 'package:flutter/material.dart';

class AppTheme {
  // Vibrant, Dark Mode, Glassmorphism aesthetic tokens
  static const Color primaryColor = Color(0xFF6C63FF);
  static const Color secondaryColor = Color(0xFF00BFA6);
  static const Color backgroundColor = Color(0xFF121212);
  static const Color surfaceColor = Color(0xFF1E1E1E);
  static const Color errorColor = Color(0xFFFF5252);
  static const Color textHighEmphasis = Color(0xFFFFFFFF);
  static const Color textMediumEmphasis = Color(0xB3FFFFFF);

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: const Color(0xFF00E5FF),
      scaffoldBackgroundColor: const Color(0xFF0F0F0F),
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF00E5FF),
        secondary: Color(0xFF00B8D4),
        surface: Color(0xFF1A1A1A),
        error: Colors.redAccent,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF0F0F0F),
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 8,
        shadowColor: Colors.black.withValues(alpha: 0.5),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF252525),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF00E5FF), width: 1),
        ),
        labelStyle: const TextStyle(color: Colors.grey),
        hintStyle: const TextStyle(color: Colors.white38),
      ),
      fontFamily: 'Inter',
      useMaterial3: true,
    );
  }
}
