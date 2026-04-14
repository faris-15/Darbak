import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'auth_screens.dart';

void main() {
  runApp(const DarbakApp());
}

class DarbakApp extends StatelessWidget {
  const DarbakApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Darbak',
      debugShowCheckedModeBanner: false,
      theme: DarbakTheme.lightTheme,
      home: const SplashScreen(),
      routes: {
        '/login': (_) => const LoginScreen(),
        '/roleSelection': (_) => const ChooseRoleScreen(),
        '/splash': (_) => const SplashScreen(),
      },
    );
  }
}
