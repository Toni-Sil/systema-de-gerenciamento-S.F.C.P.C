import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';

class _OnboardingPage {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  const _OnboardingPage({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
  });
}

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onFinished;
  const OnboardingScreen({super.key, required this.onFinished});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _ctrl = PageController();
  int _current = 0;

  static const _pages = [
    _OnboardingPage(
      icon: Icons.psychology,
      iconColor: AppColors.neonCyan,
      title: 'Agente IA Integrado',
      subtitle:
          'Converse com a IA para consultar estoque, gerar relatórios e tomar decisões em tempo real.',
    ),
    _OnboardingPage(
      icon: Icons.inventory_2,
      iconColor: AppColors.neonGreen,
      title: 'Gestão Operacional',
      subtitle:
          'Scanner de código de barras, controle de estoque e alertas automáticos de reposição.',
    ),
    _OnboardingPage(
      icon: Icons.calendar_month,
      iconColor: AppColors.neonPurple,
      title: 'Agenda por Voz',
      subtitle:
          'Crie eventos falando naturalmente: "Reunião com fornecedor amanhã às 14h" e receba notificações automáticas.',
    ),
    _OnboardingPage(
      icon: Icons.bar_chart,
      iconColor: AppColors.neonAmber,
      title: 'Indicadores em Tempo Real',
      subtitle:
          'Dashboard com Curva ABC, tendência de demanda, capital empatado e giro de estoque.',
    ),
  ];

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', true);
    widget.onFinished();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgBase,
      body: SafeArea(
        child: Column(
          children: [
            // Skip
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: _finish,
                child: const Text('Pular',
                    style: TextStyle(color: AppColors.textLow)),
              ),
            ),
            // Páginas
            Expanded(
              child: PageView.builder(
                controller: _ctrl,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _current = i),
                itemBuilder: (_, i) => _buildPage(_pages[i]),
              ),
            ),
            // Indicadores
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _pages.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _current == i ? 20 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: _current == i
                        ? AppColors.neonCyan
                        : AppColors.border,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            // Botão
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (_current < _pages.length - 1) {
                      _ctrl.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut);
                    } else {
                      _finish();
                    }
                  },
                  child: Text(
                    _current < _pages.length - 1 ? 'Próximo' : 'Começar',
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildPage(_OnboardingPage page) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: page.iconColor.withValues(alpha: 0.1),
              border: Border.all(
                  color: page.iconColor.withValues(alpha: 0.4), width: 2),
            ),
            child: Icon(page.icon, size: 56, color: page.iconColor),
          ),
          const SizedBox(height: 40),
          Text(
            page.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: AppColors.textHigh,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            page.subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              color: AppColors.textMed,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
