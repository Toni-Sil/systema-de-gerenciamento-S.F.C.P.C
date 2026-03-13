import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'presentation/theme/app_theme.dart';
import 'presentation/screens/home_screen.dart';

import 'package:frontend/core/providers/user_provider.dart';
import 'package:frontend/core/providers/operational_provider.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => OperationalProvider()),
      ],
      child: const SFCpcApp(),
    ),
  );
}

class SFCpcApp extends StatelessWidget {
  const SFCpcApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'S.F.C.P.C AI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const HomeScreen(),
    );
  }
}
