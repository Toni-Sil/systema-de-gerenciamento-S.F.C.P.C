import 'package:flutter/material.dart';
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

  final List<Widget> _screens = [
    const AgentScreen(),
    const DashboardScreen(),
    const OperationalScreen(),
    const FinancialScreen(),
    const SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    // Dynamic Bottom Navigation based on the 5 pillars
    return Scaffold(
      appBar: AppBar(
        title: const Text('S.F.C.P.C - Logística Agêntica'),
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
          onTap: (index) => setState(() => _currentIndex = index),
          type: BottomNavigationBarType.fixed,
          backgroundColor: Theme.of(context).colorScheme.surface,
          selectedItemColor: Theme.of(context).primaryColor,
          unselectedItemColor: Colors.white38,
          showUnselectedLabels: true,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          unselectedLabelStyle: const TextStyle(fontSize: 10),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.psychology_outlined),
              activeIcon: Icon(Icons.psychology),
              label: 'Agente IA',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.bar_chart_outlined),
              activeIcon: Icon(Icons.bar_chart),
              label: 'Indicadores',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.inventory_2_outlined),
              activeIcon: Icon(Icons.inventory_2),
              label: 'Operacional',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.account_balance_wallet_outlined),
              activeIcon: Icon(Icons.account_balance_wallet),
              label: 'Financeiro',
            ),
            BottomNavigationBarItem(
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
