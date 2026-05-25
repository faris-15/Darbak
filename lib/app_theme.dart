import 'package:flutter/material.dart';

class DarbakColors {
  DarbakColors._();

  // اللون الأساسي (أخضر اللوقو)
  static const Color primaryGreen = Color(0xFF088A3B);
  static const Color primary = Color(0xff168A57);
  static const Color primaryDark = Color(0xff0E6D44);

  // رمادي داكن للنصوص
  static const Color dark = Color(0xFF222831);
  static const Color text = Color(0xff1B1F24);

  // رمادي فاتح للخلفيات
  static const Color lightBackground = Color(0xFFF5F5F5);
  static const Color background = Color(0xffF5F7FA);

  // رمادي للبطاقات
  static const Color cardBackground = Color(0xFFF0F0F0);
  static const Color card = Colors.white;

  // أصفر تحذيري
  static const Color warningYellow = Color(0xFFFFC93C);
  static const Color orange = Color(0xffF59E0B);

  // أخضر ناجح (لإتمام العملية)
  static const Color successGreen = Color(0xFF2ECC71);
  static const Color success = Color(0xff79C96B);
  static const Color lightGreen = Color(0xffE9F8F0);

  // حدود فاتحة
  static const Color border = Color(0xFFE0E0E0);
  static const Color borderSoft = Color(0xffE6E9EF);

  // نص ثانوي
  static const Color textSecondary = Color(0xFF777777);
  static const Color subText = Color(0xff6B7280);
  static const Color danger = Color(0xffD94C4C);
}

class DarbakTypography {
  DarbakTypography._();

  static const String fontFamily = 'NotoSansArabic';

  static const TextStyle _base = TextStyle(
    fontFamily: fontFamily,
    height: 1.35,
    leadingDistribution: TextLeadingDistribution.even,
  );

  static TextStyle style({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? height,
  }) {
    return _base.copyWith(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
    );
  }

  static final TextTheme textTheme = TextTheme(
    displayLarge: style(
      fontSize: 32,
      fontWeight: FontWeight.w800,
      color: DarbakColors.text,
      height: 1.25,
    ),
    displayMedium: style(
      fontSize: 28,
      fontWeight: FontWeight.w800,
      color: DarbakColors.text,
      height: 1.28,
    ),
    displaySmall: style(
      fontSize: 24,
      fontWeight: FontWeight.w800,
      color: DarbakColors.text,
      height: 1.3,
    ),
    headlineLarge: style(
      fontSize: 22,
      fontWeight: FontWeight.w800,
      color: DarbakColors.text,
      height: 1.32,
    ),
    headlineMedium: style(
      fontSize: 20,
      fontWeight: FontWeight.w800,
      color: DarbakColors.text,
    ),
    headlineSmall: style(
      fontSize: 18,
      fontWeight: FontWeight.w700,
      color: DarbakColors.text,
    ),
    titleLarge: style(
      fontSize: 18,
      fontWeight: FontWeight.w700,
      color: DarbakColors.text,
    ),
    titleMedium: style(
      fontSize: 16,
      fontWeight: FontWeight.w700,
      color: DarbakColors.text,
    ),
    titleSmall: style(
      fontSize: 14,
      fontWeight: FontWeight.w700,
      color: DarbakColors.text,
    ),
    bodyLarge: style(
      fontSize: 16,
      fontWeight: FontWeight.w400,
      color: DarbakColors.text,
      height: 1.55,
    ),
    bodyMedium: style(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      color: DarbakColors.text,
      height: 1.5,
    ),
    bodySmall: style(
      fontSize: 12,
      fontWeight: FontWeight.w400,
      color: DarbakColors.subText,
      height: 1.45,
    ),
    labelLarge: style(
      fontSize: 15,
      fontWeight: FontWeight.w700,
      color: DarbakColors.text,
    ),
    labelMedium: style(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: DarbakColors.text,
    ),
    labelSmall: style(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      color: DarbakColors.subText,
    ),
  );
}

class DarbakSpacing {
  DarbakSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

class DarbakRadius {
  DarbakRadius._();

  static const double sm = 12;
  static const double md = 16;
  static const double lg = 22;
  static const double xl = 26;
  static const double pill = 999;
}

class DarbakShadows {
  DarbakShadows._();

  static List<BoxShadow> get card => [
    BoxShadow(
      color: Colors.black.withValues(alpha: .04),
      blurRadius: 22,
      offset: const Offset(0, 12),
    ),
  ];

  static List<BoxShadow> get soft => [
    BoxShadow(
      color: Colors.black.withValues(alpha: .03),
      blurRadius: 18,
      offset: const Offset(0, 10),
    ),
  ];
}

class DarbakTheme {
  DarbakTheme._();

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    fontFamily: DarbakTypography.fontFamily,
    fontFamilyFallback: const ['Arial', 'Tahoma'],
    textTheme: DarbakTypography.textTheme,
    colorScheme: ColorScheme.fromSeed(
      seedColor: DarbakColors.primary,
      primary: DarbakColors.primary,
      secondary: DarbakColors.primaryDark,
      error: DarbakColors.danger,
      surface: DarbakColors.card,
    ),
    scaffoldBackgroundColor: Colors.white,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      elevation: 0,
      foregroundColor: DarbakColors.text,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontFamily: DarbakTypography.fontFamily,
        color: DarbakColors.text,
        fontSize: 20,
        fontWeight: FontWeight.w800,
        height: 1.35,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: DarbakSpacing.lg,
        vertical: 14,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(DarbakRadius.pill),
        borderSide: const BorderSide(color: DarbakColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(DarbakRadius.pill),
        borderSide: const BorderSide(color: DarbakColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(DarbakRadius.pill),
        borderSide: const BorderSide(color: DarbakColors.primary, width: 1.5),
      ),
      hintStyle: const TextStyle(
        color: DarbakColors.textSecondary,
        fontSize: 13,
        height: 1.35,
      ),
      labelStyle: const TextStyle(
        color: DarbakColors.subText,
        fontSize: 13,
        height: 1.35,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: DarbakColors.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(52),
        textStyle: DarbakTypography.style(
          fontSize: 16,
          fontWeight: FontWeight.w800,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DarbakRadius.md),
        ),
        elevation: 2,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: DarbakColors.primary,
        side: const BorderSide(color: DarbakColors.borderSoft),
        textStyle: DarbakTypography.style(
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DarbakRadius.md),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: DarbakColors.primary,
        textStyle: DarbakTypography.style(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    cardTheme: CardThemeData(
      color: DarbakColors.card,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DarbakRadius.lg),
        side: const BorderSide(color: DarbakColors.borderSoft),
      ),
    ),
    dialogTheme: DialogThemeData(
      titleTextStyle: DarbakTypography.textTheme.titleLarge,
      contentTextStyle: DarbakTypography.textTheme.bodyMedium,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DarbakRadius.lg),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      contentTextStyle: DarbakTypography.style(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
