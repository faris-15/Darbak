import 'package:flutter/material.dart';

class DarbakColors {
  DarbakColors._();

  // اللون الأساسي (أخضر اللوقو)
  static const Color primaryGreen = Color(0xFF088A3B);

  // رمادي داكن للنصوص
  static const Color dark = Color(0xFF222831);

  // رمادي فاتح للخلفيات
  static const Color lightBackground = Color(0xFFF5F5F5);

  // رمادي للبطاقات
  static const Color cardBackground = Color(0xFFF0F0F0);

  // أصفر تحذيري
  static const Color warningYellow = Color(0xFFFFC93C);

  // أخضر ناجح (لإتمام العملية)
  static const Color successGreen = Color(0xFF2ECC71);

  // حدود فاتحة
  static const Color border = Color(0xFFE0E0E0);

  // نص ثانوي
  static const Color textSecondary = Color(0xFF777777);
}

class DarbakTheme {
  DarbakTheme._();

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    fontFamily: 'Cairo', // لو ما عندك الخط، يمكنك حذفه
    colorScheme: ColorScheme.fromSeed(
      seedColor: DarbakColors.primaryGreen,
      primary: DarbakColors.primaryGreen,
    ),
    scaffoldBackgroundColor: Colors.white,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      elevation: 0,
      foregroundColor: DarbakColors.dark,
      centerTitle: true,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(999),
        borderSide: const BorderSide(color: DarbakColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(999),
        borderSide: const BorderSide(color: DarbakColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(999),
        borderSide: const BorderSide(color: DarbakColors.primaryGreen, width: 1.5),
      ),
      hintStyle: const TextStyle(
        color: DarbakColors.textSecondary,
        fontSize: 13,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: DarbakColors.primaryGreen,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: 3,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: DarbakColors.primaryGreen,
        textStyle: const TextStyle(
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );
}
