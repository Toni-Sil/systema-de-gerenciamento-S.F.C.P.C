// Sprint 1 — Tour de Onboarding com tutorial_coach_mark
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onFinished;
  const OnboardingScreen({super.key, required this.onFinished});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageCtrl = PageController();
  int _currentPage = 0;

  final List<_OnboardPage> _pages = const [
    _OnboardPage(
      icon: Icons.psychology,
      color: AppColors.neonCyan,
      title: 'Agente IA no Controle',
      subtitle:
          'Diga em português o que precisa.\n"Dar entrada 50m tecido floral" — pronto!',
    ),
    _OnboardPage(
      icon: Icons.qr_code_scanner,
      color: AppColors.neonPurple,
      title: 'Scanner Inteligente',
      subtitle:
          'Escaneie código de barras ou QR Code\npara entrada/saída instantânea de itens.',
    ),
    _OnboardPage(
      icon: Icons.document_scanner_outlined,
      color: AppColors.neonGreen,
      title: 'OCR de Nota Fiscal',
      subtitle:
          'Fotografe a NF e a IA preenche\nautomaticamente todos os campos.',
    ),
    _OnboardPage(
      icon: Icons.bar_chart,
      color: AppColors.neonAmber,
      title: 'Dashboard em Tempo Real',
      subtitle:
          'KPIs, Curva ABC e tendência de demanda\natualizados automaticamente.',
    ),
    _OnboardPage(
      icon: Icons.whatsapp,
      color: Color(0xFF25D366),
      title: 'WhatsApp Integrado',
      subtitle:
          'Envie relatórios e alertas de estoque\ndiretamente pelo WhatsApp.',
    ),
  ];

  void _next() {
    if (_currentPage < _pages.length - 1) {
      _pageCtrl.nextPage(
          duration: const Duration(milliseconds: 350), curve: Curves.easeOut);
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', true);
    widget.onFinished();
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
                child: const Text('Pular', style: TextStyle(color: AppColors.textLow)),
              ),
            ),
            // Pages
            Expanded(
              child: PageView.builder(
                controller: _pageCtrl,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemBuilder: (_, i) => _buildPage(_pages[i]),
              ),
            ),
            // Dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _pages.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: i == _currentPage ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: i == _currentPage
                        ? _pages[_currentPage].color
                        : AppColors.textLow,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            // Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _next,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _pages[_currentPage].color,
                    foregroundColor: AppColors.bgDeep,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(
                    _currentPage < _pages.length - 1 ? 'Próximo' : 'Começar!',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildPage(_OnboardPage page) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: page.color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(color: page.color.withValues(alpha: 0.4), width: 2),
            ),
            child: Icon(page.icon, size: 56, color: page.color),
          ),
          const SizedBox(height: 40),
          Text(
            page.title,
            style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: AppColors.textHigh),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            page.subtitle,
            style: const TextStyle(
                fontSize: 15,
                color: AppColors.textMed,
                height: 1.6),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _OnboardPage {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  const _OnboardPage(
      {required this.icon,
      required this.color,
      required this.title,
      required this.subtitle});
}
