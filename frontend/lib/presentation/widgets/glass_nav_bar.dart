import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:frontend/presentation/theme/app_theme.dart';

/// Bottom navigation bar com efeito glassmorphism.
/// Usa BackdropFilter + ImageFilter.blur para frosted-glass.
/// Transparente por baixo — o content do Scaffold aparece atras.
class GlassNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<BottomNavigationBarItem> items;

  const GlassNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final glassColor =
        isDark ? AppColors.glassNav : AppColors.glassNavLight;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.06);
    final selectedColor =
        isDark ? AppColors.neonCyan : AppColors.neonCyan;
    final unselectedColor =
        isDark ? Colors.white38 : const Color(0xFF888899);

    // Altura da barra + padding do sistema (home indicator no iOS/Android)
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          decoration: BoxDecoration(
            color: glassColor,
            border: Border(
              top: BorderSide(color: borderColor, width: 0.5),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.only(bottom: bottomPadding),
            child: BottomNavigationBar(
              currentIndex: currentIndex,
              onTap: onTap,
              type: BottomNavigationBarType.fixed,
              backgroundColor: Colors.transparent,
              selectedItemColor: selectedColor,
              unselectedItemColor: unselectedColor,
              showUnselectedLabels: true,
              elevation: 0,
              selectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 11,
                fontFamily: 'Inter',
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 10,
                fontFamily: 'Inter',
              ),
              items: items,
            ),
          ),
        ),
      ),
    );
  }
}
