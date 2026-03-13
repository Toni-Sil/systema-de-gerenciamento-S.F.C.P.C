import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppColors {
  // Paleta Cyberpunk Sofá-Cama 2026
  static const Color neonCyan    = Color(0xFF00E5FF);
  static const Color neonPurple  = Color(0xFF8B5CF6);
  static const Color neonGreen   = Color(0xFF10B981);
  static const Color neonAmber   = Color(0xFFF59E0B);
  static const Color neonRed     = Color(0xFFEF4444);

  static const Color bgDeep      = Color(0xFF080810);
  static const Color bgBase      = Color(0xFF0F0F1A);
  static const Color bgSurface   = Color(0xFF16162A);
  static const Color bgCard      = Color(0xFF1C1C32);
  static const Color bgGlass     = Color(0x1AFFFFFF);

  static const Color textHigh    = Color(0xFFFFFFFF);
  static const Color textMed     = Color(0xB3FFFFFF);
  static const Color textLow     = Color(0x66FFFFFF);
  static const Color border      = Color(0x1AFFFFFF);

  // Gradientes
  static const LinearGradient gradientPrimary = LinearGradient(
    colors: [Color(0xFF00E5FF), Color(0xFF8B5CF6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient gradientSuccess = LinearGradient(
    colors: [Color(0xFF10B981), Color(0xFF00E5FF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient gradientWarn = LinearGradient(
    colors: [Color(0xFFF59E0B), Color(0xFFEF4444)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient gradientBg = LinearGradient(
    colors: [Color(0xFF080810), Color(0xFF0D0D20)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: AppColors.neonCyan,
      scaffoldBackgroundColor: AppColors.bgBase,
      fontFamily: 'Inter',
      useMaterial3: true,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.neonCyan,
        secondary: AppColors.neonPurple,
        tertiary: AppColors.neonGreen,
        surface: AppColors.bgSurface,
        error: AppColors.neonRed,
        onPrimary: AppColors.bgDeep,
        onSecondary: AppColors.textHigh,
        onSurface: AppColors.textHigh,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
        ),
        titleTextStyle: TextStyle(
          color: AppColors.textHigh,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          fontFamily: 'Inter',
        ),
        iconTheme: IconThemeData(color: AppColors.textHigh),
      ),
      cardTheme: CardThemeData(
        color: AppColors.bgCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppColors.border),
        ),
        elevation: 0,
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.bgSurface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.neonCyan, width: 1.5),
        ),
        labelStyle: const TextStyle(color: AppColors.textLow, fontFamily: 'Inter'),
        hintStyle: const TextStyle(color: AppColors.textLow, fontFamily: 'Inter'),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.neonCyan,
          foregroundColor: AppColors.bgDeep,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, fontFamily: 'Inter'),
          elevation: 0,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.neonCyan,
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontFamily: 'Inter'),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.bgSurface,
        selectedColor: AppColors.neonCyan.withValues(alpha: 0.2),
        labelStyle: const TextStyle(color: AppColors.textMed, fontSize: 12, fontFamily: 'Inter'),
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.bgCard,
        selectedItemColor: AppColors.neonCyan,
        unselectedItemColor: AppColors.textLow,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, fontFamily: 'Inter'),
        unselectedLabelStyle: TextStyle(fontSize: 10, fontFamily: 'Inter'),
      ),
    );
  }
}
