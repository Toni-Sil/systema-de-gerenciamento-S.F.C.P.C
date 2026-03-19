// SEC #4: AgendaProvider.init() chamado no bootstrap
// v2: ThemeProvider integrado — dark/light persistido em SharedPreferences
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
import 'core/providers/theme_provider.dart';
import 'core/services/offline_sync_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // SystemUI inicial — sera atualizado pelo ThemeProvider apos init()
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  // Barra de navegacao do sistema tambem transparente (funciona com extendBody)
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  await OfflineSyncService.init();

  final userProvider = UserProvider();
  await userProvider.init();

  final agendaProvider = AgendaProvider();
  await agendaProvider.init();

  // ThemeProvider carrega preferencia salva antes do runApp
  final themeProvider = ThemeProvider();
  await themeProvider.init();

  final prefs = await SharedPreferences.getInstance();
  final onboardingDone = prefs.getBool('onboarding_done') ?? false;

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: userProvider),
        ChangeNotifierProvider.value(value: agendaProvider),
        ChangeNotifierProvider.value(value: themeProvider),
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
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDark;

    // Atualiza icones da status bar conforme o tema ativo
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness:
          isDark ? Brightness.light : Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness:
          isDark ? Brightness.light : Brightness.dark,
    ));

    return MaterialApp(
      title: 'S.F.C.P.C AI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeProvider.mode,
      home: Builder(
        builder: (context) => showOnboarding
            ? OnboardingScreen(
                onFinished: () =>
                    Navigator.pushReplacementNamed(context, '/home'))
            : const HomeScreen(),
      ),
      routes: {
        '/home': (_) => const HomeScreen(),
      },
    );
  }
}
