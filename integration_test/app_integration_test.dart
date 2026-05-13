import 'package:darbak/app_theme.dart';
import 'package:darbak/auth_screens.dart';
import 'package:darbak/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Darbak integration', () {
    testWidgets('DarbakApp launches without throwing', (tester) async {
      await tester.pumpWidget(const DarbakApp());
      await tester.pump();
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('LoginScreen is visible with expected chrome', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: DarbakTheme.lightTheme,
          home: const LoginScreen(),
        ),
      );
      expect(find.text('تسجيل الدخول'), findsWidgets);
      expect(find.text('متابعة'), findsOneWidget);
    });

    testWidgets('empty login shows SnackBar error feedback', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: DarbakTheme.lightTheme,
          home: const LoginScreen(),
        ),
      );

      await tester.tap(find.text('متابعة'));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(find.byType(SnackBar), findsWidgets);
    });

    testWidgets('navigation to role selection does not crash', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: DarbakTheme.lightTheme,
          initialRoute: '/login',
          routes: {
            '/login': (_) => const LoginScreen(),
            '/roleSelection': (_) => const ChooseRoleScreen(),
          },
        ),
      );

      await tester.tap(find.text('سجل الآن'));
      await tester.pumpAndSettle();

      expect(find.textContaining('اختر نوع حسابك'), findsWidgets);
    });
  });
}
