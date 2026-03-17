// v2: GlassNavBar + AnimatedSwitcher com FadeTransition entre tabs
// FIX #1: removido AgendaProvider.init() duplicado do initState
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:frontend/core/providers/user_provider.dart';
import 'package:frontend/core/providers/operational_provider.dart';
import 'package:frontend/core/providers/agenda_provider.dart';
import 'package:frontend/core/providers/theme_provider.dart';
import 'package:frontend/presentation/theme/app_theme.dart';
import 'package:frontend/presentation/widgets/glass_nav_bar.dart';
import 'agent_screen.dart';
import 'agenda_screen.dart';
import 'dashboard_screen.dart';
import 'operational_screen.dart';
import 'financial_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  int _previousIndex = 0;

  static const _titles = [
    'Agente IA',
    'Indicadores',
    'Operacional',
    'Financeiro',
    'Agenda',
    'Governança',
  ];

  final List<Widget> _screens = const [
    AgentScreen(),
    DashboardScreen(),
    OperationalScreen(),
    FinancialScreen(),
    AgendaScreen(),
    SettingsScreen(),
  ];

  void _onTabTap(int index) {
    if (index == _currentIndex) return;
    setState(() {
      _previousIndex = _currentIndex;
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final opProvider = Provider.of<OperationalProvider>(context);
    final agendaProvider = Provider.of<AgendaProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final alertCount = opProvider.lowStockItems.length;
    final todayEvents = agendaProvider.todayCount;
    final isDark = themeProvider.isDark;

    return Scaffold(
      extendBody: true, // body aparece atras da GlassNavBar
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _titles[_currentIndex],
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.textHigh : AppColors.lgTextHigh,
              ),
            ),
            Text(
              userProvider.companyName,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? AppColors.textLow : AppColors.lgTextLow,
              ),
            ),
          ],
        ),
        actions: [
          // Toggle dark/light
          IconButton(
            icon: Icon(
              isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
              color: isDark ? AppColors.textLow : AppColors.lgTextMed,
              size: 20,
            ),
            onPressed: () => themeProvider.toggle(),
            tooltip: isDark ? 'Modo claro' : 'Modo escuro',
          ),
          if (alertCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.notifications_outlined,
                      color: isDark ? AppColors.textLow : AppColors.lgTextMed,
                    ),
                    onPressed: () => _onTabTap(2),
                    tooltip: '$alertCount itens para repor',
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: const BoxDecoration(
                        color: AppColors.neonRed,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          alertCount > 9 ? '9+' : '$alertCount',
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          GestureDetector(
            onTap: () => _onTabTap(5),
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: CircleAvatar(
                radius: 18,
                backgroundImage: NetworkImage(userProvider.profileImageUrl),
                backgroundColor: AppColors.neonCyan.withValues(alpha: 0.2),
              ),
            ),
          ),
        ],
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
      ),

      // AnimatedSwitcher com FadeTransition entre tabs
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: Curves.easeInOut,
          ),
          child: child,
        ),
        child: KeyedSubtree(
          key: ValueKey<int>(_currentIndex),
          child: _screens[_currentIndex],
        ),
      ),

      // Glassmorphism bottom nav
      bottomNavigationBar: GlassNavBar(
        currentIndex: _currentIndex,
        onTap: _onTabTap,
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.psychology_outlined),
            activeIcon: Icon(Icons.psychology),
            label: 'Agente IA',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart_outlined),
            activeIcon: Icon(Icons.bar_chart),
            label: 'Indicadores',
          ),
          BottomNavigationBarItem(
            icon: alertCount > 0
                ? Badge(
                    label: Text('$alertCount'),
                    child: const Icon(Icons.inventory_2_outlined))
                : const Icon(Icons.inventory_2_outlined),
            activeIcon: alertCount > 0
                ? Badge(
                    label: Text('$alertCount'),
                    child: const Icon(Icons.inventory_2))
                : const Icon(Icons.inventory_2),
            label: 'Operacional',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet_outlined),
            activeIcon: Icon(Icons.account_balance_wallet),
            label: 'Financeiro',
          ),
          BottomNavigationBarItem(
            icon: todayEvents > 0
                ? Badge(
                    label: Text('$todayEvents'),
                    child: const Icon(Icons.calendar_month_outlined))
                : const Icon(Icons.calendar_month_outlined),
            activeIcon: todayEvents > 0
                ? Badge(
                    label: Text('$todayEvents'),
                    child: const Icon(Icons.calendar_month))
                : const Icon(Icons.calendar_month),
            label: 'Agenda',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.admin_panel_settings_outlined),
            activeIcon: Icon(Icons.admin_panel_settings),
            label: 'Governânça',
          ),
        ],
      ),
    );
  }
}
