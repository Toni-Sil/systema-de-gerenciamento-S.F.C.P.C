import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'presentation/theme/app_theme.dart';
import 'presentation/screens/home_screen.dart';
import 'presentation/screens/onboarding_screen.dart';
import 'core/providers/user_provider.dart';
import 'core/providers/operational_provider.dart';
import 'core/services/offline_sync_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializa serviços base
  await OfflineSyncService.init();

  // Inicializa providers com dados persistidos
  final userProvider = UserProvider();
  await userProvider.init();

  final prefs = await SharedPreferences.getInstance();
  final onboardingDone = prefs.getBool('onboarding_done') ?? false;

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: userProvider),
        ChangeNotifierProvider(create: (_) => OperationalProvider()),
      ],
      child: SFCpcApp(
        showOnboarding: !onboardingDone,
        isAuthenticated: userProvider.isAuthenticated,
      ),
    ),
  );
}

class SFCpcApp extends StatelessWidget {
  final bool showOnboarding;
  final bool isAuthenticated;
  const SFCpcApp({
    super.key,
    required this.showOnboarding,
    required this.isAuthenticated,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'S.F.C.P.C AI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: showOnboarding
          ? OnboardingScreen(
              onFinished: () => Navigator.pushReplacementNamed(
                  context, '/home'))
          : const HomeScreen(),
      routes: {
        '/home': (_) => const HomeScreen(),
      },
    );
  }
}
