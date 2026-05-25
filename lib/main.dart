// تهيئة Firebase ثم تشغيل التطبيق (إعادة تعيين كلمة المرور عبر FirebaseAuth).
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app_theme.dart';
import 'auth_screens.dart';
import 'firebase_options.dart';
import 'services/profile_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await FirebaseAuth.instance.setLanguageCode('ar');
  await ProfileRepository.hydrateFromPrefs();
  runApp(const DarbakApp());
}

class DarbakApp extends StatelessWidget {
  const DarbakApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Darbak',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar', 'SA'),
      supportedLocales: const [Locale('ar', 'SA')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: DarbakTheme.lightTheme,
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const SplashScreen(),
      routes: {
        '/login': (_) => const LoginScreen(),
        '/roleSelection': (_) => const ChooseRoleScreen(),
        '/splash': (_) => const SplashScreen(),
      },
    );
  }
}
