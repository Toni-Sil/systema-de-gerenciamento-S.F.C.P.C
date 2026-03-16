// PR-D — HomeScreen: AppBar dinâmica com nome/avatar do UserProvider, badge de alerta, título por aba
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:frontend/core/providers/user_provider.dart';
import 'package:frontend/core/providers/operational_provider.dart';
import 'package:frontend/presentation/theme/app_theme.dart';
import 'agent_screen.dart';
import 'dashboard_screen.dart';
import 'operational_screen.dart';
import 'financial_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  static const _titles = [
    'Agente IA',
    'Indicadores',
    'Operacional',
    'Financeiro',
    'Governança',
  ];

  final List<Widget> _screens = [
    const AgentScreen(),
    const DashboardScreen(),
    const OperationalScreen(),
    const FinancialScreen(),
    const SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final opProvider = Provider.of<OperationalProvider>(context);
    final alertCount = opProvider.lowStockItems.length;

    return Scaffold(
      appBar: AppBar(
        // Título muda conforme aba
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _titles[_currentIndex],
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textHigh),
            ),
            Text(
              userProvider.companyName,
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textLow),
            ),
          ],
        ),
        actions: [
          // Badge de alertas de reposicão
          if (alertCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_outlined,
                        color: AppColors.textLow),
                    onPressed: () =>
                        setState(() => _currentIndex = 2), // vai para Operacional
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
                              color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          // Avatar
          GestureDetector(
            onTap: () => setState(() => _currentIndex = 4),
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: CircleAvatar(
                radius: 18,
                backgroundImage:
                    NetworkImage(userProvider.profileImageUrl),
                backgroundColor:
                    AppColors.neonCyan.withValues(alpha: 0.2),
              ),
            ),
          ),
        ],
        elevation: 0,
        backgroundColor:
            Theme.of(context).scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (i) => setState(() => _currentIndex = i),
          type: BottomNavigationBarType.fixed,
          backgroundColor: Theme.of(context).colorScheme.surface,
          selectedItemColor: AppColors.neonCyan,
          unselectedItemColor: Colors.white38,
          showUnselectedLabels: true,
          selectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.bold, fontSize: 12),
          unselectedLabelStyle: const TextStyle(fontSize: 10),
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
            // Badge no item Operacional se houver alertas
            BottomNavigationBarItem(
              icon: alertCount > 0
                  ? Badge(
                      label: Text('$alertCount'),
                      child: const Icon(Icons.inventory_2_outlined),
                    )
                  : const Icon(Icons.inventory_2_outlined),
              activeIcon: alertCount > 0
                  ? Badge(
                      label: Text('$alertCount'),
                      child: const Icon(Icons.inventory_2),
                    )
                  : const Icon(Icons.inventory_2),
              label: 'Operacional',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.account_balance_wallet_outlined),
              activeIcon: Icon(Icons.account_balance_wallet),
              label: 'Financeiro',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.admin_panel_settings_outlined),
              activeIcon: Icon(Icons.admin_panel_settings),
              label: 'Governança',
            ),
          ],
        ),
      ),
    );
  }
}
