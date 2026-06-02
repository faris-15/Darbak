import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:darbak/app_theme.dart';

Widget buildTestApp(Widget child) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    locale: const Locale('ar', 'SA'),
    supportedLocales: const [Locale('ar', 'SA')],
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    theme: DarbakTheme.lightTheme,
    home: Directionality(textDirection: TextDirection.rtl, child: child),
  );
}
