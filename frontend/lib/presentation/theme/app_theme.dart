import 'package:flutter/material.dart';

/// Tokens de design centralizados — S.F.C.P.C 2026
class AppColors {
  AppColors._();

  // ─ Backgrounds
  static const Color bgDeep    = Color(0xFF0A0A0F); // mais escuro (splash/gradiente)
  static const Color bgBase    = Color(0xFF0F0F0F); // fundo principal
  static const Color bgCard    = Color(0xFF1A1A1A); // cards
  static const Color bgSurface = Color(0xFF252525); // inputs / surface elevado

  // ─ Borders
  static const Color border    = Color(0xFF2A2A2A);

  // ─ Text
  static const Color textHigh  = Color(0xFFFFFFFF);
  static const Color textMed   = Color(0xB3FFFFFF); // 70% white
  static const Color textLow   = Color(0x66FFFFFF); // 40% white

  // ─ Neon Brand
  static const Color neonCyan   = Color(0xFF00E5FF);
  static const Color neonPurple = Color(0xFF7C3AED);
  static const Color neonGreen  = Color(0xFF10B981);
  static const Color neonRed    = Color(0xFFEF4444);
  static const Color neonAmber  = Color(0xFFF59E0B);

  // ─ Gradients
  static const LinearGradient gradientBg = LinearGradient(
    colors: [Color(0xFF0A0A0F), Color(0xFF0F0F18)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient gradientCyan = LinearGradient(
    colors: [neonCyan, neonPurple],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class AppTheme {
  AppTheme._();

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: AppColors.neonCyan,
      scaffoldBackgroundColor: AppColors.bgBase,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.neonCyan,
        secondary: Color(0xFF00B8D4),
        surface: AppColors.bgCard,
        error: AppColors.neonRed,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.bgBase,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AppColors.textHigh,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: IconThemeData(color: AppColors.textLow),
      ),
      cardTheme: CardThemeData(
        color: AppColors.bgCard,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        elevation: 0,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.bgCard,
        selectedItemColor: AppColors.neonCyan,
        unselectedItemColor: Color(0x66FFFFFF),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.bgSurface,
        selectedColor: AppColors.neonCyan.withValues(alpha: 0.2),
        labelStyle: const TextStyle(color: AppColors.textMed, fontSize: 12),
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.bgSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: AppColors.neonCyan, width: 1.5),
        ),
        labelStyle: const TextStyle(color: AppColors.textLow),
        hintStyle: const TextStyle(color: AppColors.textLow),
        prefixIconColor: AppColors.textLow,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.neonCyan,
          foregroundColor: AppColors.bgDeep,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          padding:
              const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          textStyle: const TextStyle(
              fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.neonCyan,
          side: const BorderSide(color: AppColors.neonCyan),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          padding:
              const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
            foregroundColor: AppColors.neonCyan),
      ),
      dropdownMenuTheme: const DropdownMenuThemeData(
        inputDecorationTheme: InputDecorationTheme(
          fillColor: AppColors.bgSurface,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.bgCard,
        contentTextStyle:
            const TextStyle(color: AppColors.textHigh),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
      fontFamily: 'Inter',
      useMaterial3: true,
    );
  }
}
