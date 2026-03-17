import 'package:flutter/material.dart';

/// Tokens de design centralizados — S.F.C.P.C 2026
/// Changelog:
///   v2: bgBase #0F0F0F → #121212 (dark gray, menos fadiga ocular)
///       bgCard #1A1A1A → #1E1E1E
///       bgDeep #0A0A0F → #0D0D14
///       Adicionado: lightColors, ambos os ThemeData (dark + light)
class AppColors {
  AppColors._();

  // ─ Dark Backgrounds (refinados de pure-black para dark-gray)
  static const Color bgDeep    = Color(0xFF0D0D14); // splash/gradiente
  static const Color bgBase    = Color(0xFF121212); // fundo principal
  static const Color bgCard    = Color(0xFF1E1E1E); // cards
  static const Color bgSurface = Color(0xFF2A2A2A); // inputs / surface elevado

  // ─ Light Backgrounds
  static const Color lgBgBase    = Color(0xFFF5F5F7);
  static const Color lgBgCard    = Color(0xFFFFFFFF);
  static const Color lgBgSurface = Color(0xFFF0F0F0);

  // ─ Borders
  static const Color border      = Color(0xFF2E2E2E);
  static const Color lgBorder    = Color(0xFFE0E0E0);

  // ─ Text (dark)
  static const Color textHigh  = Color(0xFFFFFFFF);
  static const Color textMed   = Color(0xB3FFFFFF); // 70% white
  static const Color textLow   = Color(0x66FFFFFF); // 40% white

  // ─ Text (light)
  static const Color lgTextHigh = Color(0xFF0D0D14);
  static const Color lgTextMed  = Color(0xFF444455);
  static const Color lgTextLow  = Color(0xFF888899);

  // ─ Neon Brand (inalterados)
  static const Color neonCyan   = Color(0xFF00E5FF);
  static const Color neonPurple = Color(0xFF7C3AED);
  static const Color neonGreen  = Color(0xFF10B981);
  static const Color neonRed    = Color(0xFFEF4444);
  static const Color neonAmber  = Color(0xFFF59E0B);

  // ─ Gradients
  static const LinearGradient gradientBg = LinearGradient(
    colors: [Color(0xFF0D0D14), Color(0xFF121220)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient gradientCyan = LinearGradient(
    colors: [neonCyan, neonPurple],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ─ Glassmorphism bottom nav
  static const Color glassNav      = Color(0xBF1E1E1E); // 75% opaque
  static const Color glassNavLight = Color(0xCCFFFFFF); // 80% opaque white
}

class AppTheme {
  AppTheme._();

  // ───────────────────────────────────────────────────
  // DARK THEME
  // ───────────────────────────────────────────────────
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
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AppColors.textHigh,
          fontSize: 18,
          fontWeight: FontWeight.bold,
          fontFamily: 'Inter',
        ),
        iconTheme: IconThemeData(color: AppColors.textLow),
      ),
      cardTheme: CardThemeData(
        color: AppColors.bgCard,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        elevation: 0,
      ),
      // Bottom nav: transparente — cor real vem do GlassNavBar
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.transparent,
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
          borderSide: const BorderSide(color: AppColors.neonCyan, width: 1.5),
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
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.neonCyan,
          side: const BorderSide(color: AppColors.neonCyan),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.neonCyan),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.bgCard,
        contentTextStyle: const TextStyle(color: AppColors.textHigh),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
      fontFamily: 'Inter',
      useMaterial3: true,
    );
  }

  // ───────────────────────────────────────────────────
  // LIGHT THEME
  // ───────────────────────────────────────────────────
  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      primaryColor: AppColors.neonCyan,
      scaffoldBackgroundColor: AppColors.lgBgBase,
      colorScheme: ColorScheme.light(
        primary: AppColors.neonCyan,
        secondary: const Color(0xFF00B8D4),
        surface: AppColors.lgBgCard,
        error: AppColors.neonRed,
        onSurface: AppColors.lgTextHigh,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.lgBgBase,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: const TextStyle(
          color: AppColors.lgTextHigh,
          fontSize: 18,
          fontWeight: FontWeight.bold,
          fontFamily: 'Inter',
        ),
        iconTheme: const IconThemeData(color: AppColors.lgTextMed),
      ),
      cardTheme: CardThemeData(
        color: AppColors.lgBgCard,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        elevation: 0,
        shadowColor: Colors.black12,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.transparent,
        selectedItemColor: AppColors.neonCyan,
        unselectedItemColor: Color(0xFF888899),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.lgBgSurface,
        selectedColor: AppColors.neonCyan.withValues(alpha: 0.15),
        labelStyle: const TextStyle(color: AppColors.lgTextMed, fontSize: 12),
        side: const BorderSide(color: AppColors.lgBorder),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.lgBgSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.lgBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.neonCyan, width: 1.5),
        ),
        labelStyle: const TextStyle(color: AppColors.lgTextLow),
        hintStyle: const TextStyle(color: AppColors.lgTextLow),
        prefixIconColor: AppColors.lgTextLow,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.neonCyan,
          foregroundColor: AppColors.bgDeep,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.neonCyan,
          side: const BorderSide(color: AppColors.neonCyan),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.neonCyan),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.lgBgCard,
        contentTextStyle: const TextStyle(color: AppColors.lgTextHigh),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
      fontFamily: 'Inter',
      useMaterial3: true,
    );
  }
}
