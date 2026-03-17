import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'presentation/theme/app_theme.dart';
import 'presentation/screens/home_screen.dart';
import 'presentation/screens/onboarding_screen.dart';
import 'core/providers/user_provider.dart';
import 'core/providers/operational_provider.dart';
import 'core/providers/agenda_provider.dart';
import 'core/services/offline_sync_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Barra de status transparente
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFF1A1A1A),
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  // Orientação apenas retrato
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  await OfflineSyncService.init();

  final userProvider = UserProvider();
  await userProvider.init();

  final prefs = await SharedPreferences.getInstance();
  final onboardingDone = prefs.getBool('onboarding_done') ?? false;

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: userProvider),
        ChangeNotifierProvider(create: (_) => OperationalProvider()),
        // FIX: AgendaProvider registrado aqui para ficar acessível em toda a árvore
        ChangeNotifierProvider(create: (_) => AgendaProvider()),
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
              onFinished: () =>
                  Navigator.pushReplacementNamed(context, '/home'))
          : const HomeScreen(),
      routes: {
        '/home': (_) => const HomeScreen(),
      },
    );
  }
}
