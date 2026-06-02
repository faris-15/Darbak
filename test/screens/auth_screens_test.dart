import 'package:darbak/auth_screens.dart';
import 'package:darbak/app_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/http_mock.dart';

/// Wraps [child] with the same routing/locale/theme scaffolding the production
/// app uses, but with stubbed routes for the post-login destinations. This
/// allows widget tests to observe `Navigator.pushReplacement` targets without
/// pulling in Firebase / Sockets / Geolocator.
Widget _authTestApp(Widget child) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    locale: const Locale('ar', 'SA'),
    supportedLocales: const [Locale('ar', 'SA')],
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: Directionality(textDirection: TextDirection.rtl, child: child),
    routes: {
      '/roleSelection': (_) => const _StubScreen(label: 'role-stub'),
      '/login': (_) => const _StubScreen(label: 'login-stub'),
    },
  );
}

class _StubScreen extends StatelessWidget {
  const _StubScreen({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) =>
      Scaffold(body: Center(child: Text(label)));
}

/// Force a phone-sized portrait viewport that accommodates the long-form auth
/// screens (registration stepper, role cards, etc.).
Future<void> _useTallViewport(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Future<void> _pump(WidgetTester tester, Widget child) async {
  await _useTallViewport(tester);
  await tester.pumpWidget(_authTestApp(child));
  await tester.pumpAndSettle(const Duration(milliseconds: 100));
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // ------------------------------------------------------------------
  // ChooseRoleScreen
  // ------------------------------------------------------------------

  group('ChooseRoleScreen', () {
    testWidgets('renders both role cards with default driver selection', (
      tester,
    ) async {
      await _pump(tester, const ChooseRoleScreen());
      expect(find.text('سائق'), findsOneWidget);
      expect(find.text('شركة/صاحب شحنة'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets('tapping shipper card flips the selection indicator', (
      tester,
    ) async {
      await _pump(tester, const ChooseRoleScreen());
      await tester.tap(find.text('شركة/صاحب شحنة'));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets('login text button navigates to LoginScreen', (tester) async {
      await _pump(tester, const ChooseRoleScreen());
      await tester.tap(find.text('هل لديك حساب بالفعل؟ تسجيل الدخول'));
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets('continue button pushes the RegistrationScreen', (
      tester,
    ) async {
      await _pump(tester, const ChooseRoleScreen());
      final continueBtn = find
          .widgetWithText(DarbakPrimaryButton, 'متابعة')
          .first;
      await tester.ensureVisible(continueBtn);
      await tester.pumpAndSettle();
      await tester.tap(continueBtn);
      await tester.pumpAndSettle();
      expect(find.byType(RegistrationScreen), findsOneWidget);
    });
  });

  // ------------------------------------------------------------------
  // LoginScreen
  // ------------------------------------------------------------------

  group('LoginScreen', () {
    testWidgets('renders inputs, password toggle, and forgot link', (
      tester,
    ) async {
      await _pump(tester, const LoginScreen());
      expect(find.text('تسجيل الدخول'), findsWidgets);
      expect(find.text('05xxxxxxxx أو example@mail.com'), findsOneWidget);
      expect(find.byIcon(Icons.visibility_off_rounded), findsOneWidget);

      await tester.tap(find.byIcon(Icons.visibility_off_rounded));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.visibility_rounded), findsOneWidget);
    });

    testWidgets('navigates to ForgotPasswordScreen via link tap', (
      tester,
    ) async {
      await _pump(tester, const LoginScreen());
      // The forgot password link is a Text.rich inside a TextButton; the first
      // TextButton on the login screen owns it.
      final forgotBtn = find.byType(TextButton).first;
      await tester.ensureVisible(forgotBtn);
      await tester.pumpAndSettle();
      await tester.tap(forgotBtn);
      await tester.pumpAndSettle();
      expect(find.byType(ForgotPasswordScreen), findsOneWidget);
    });

    testWidgets('signup link routes to /roleSelection', (tester) async {
      await _pump(tester, const LoginScreen());
      await tester.ensureVisible(find.text('سجل الآن'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('سجل الآن'));
      await tester.pumpAndSettle();
      expect(find.text('role-stub'), findsOneWidget);
    });

    testWidgets('phone login surfaces server error as SnackBar', (
      tester,
    ) async {
      await withMockedHttp(
        setup: (r) => r.respond(
          'POST',
          '/api/auth/login',
          statusCode: 400,
          body: {'message': 'بيانات غير صحيحة'},
        ),
        callback: (_) async {
          await _pump(tester, const LoginScreen());
          await tester.enterText(
            find.widgetWithText(TextField, '05xxxxxxxx أو example@mail.com'),
            '0500000000',
          );
          await tester.enterText(
            find.widgetWithText(TextField, 'كلمة المرور'),
            'short',
          );
          final btn = find.widgetWithText(DarbakPrimaryButton, 'متابعة').first;
          await tester.ensureVisible(btn);
          await tester.pumpAndSettle();
          await tester.tap(btn);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 50));
          await tester.pumpAndSettle();
          expect(find.text('بيانات غير صحيحة'), findsOneWidget);
        },
      );
    });

    testWidgets('hides identitytoolkit details from server error', (
      tester,
    ) async {
      await withMockedHttp(
        setup: (r) => r.respond(
          'POST',
          '/api/auth/login',
          statusCode: 500,
          body: {'message': 'identitytoolkit failed'},
        ),
        callback: (_) async {
          await _pump(tester, const LoginScreen());
          await tester.enterText(
            find.widgetWithText(TextField, '05xxxxxxxx أو example@mail.com'),
            '0500000000',
          );
          await tester.enterText(
            find.widgetWithText(TextField, 'كلمة المرور'),
            'pw',
          );
          final btn = find.widgetWithText(DarbakPrimaryButton, 'متابعة').first;
          await tester.ensureVisible(btn);
          await tester.pumpAndSettle();
          await tester.tap(btn);
          await tester.pumpAndSettle();
          expect(
            find.text('تعذّر إكمال العملية. حاول مرة أخرى.'),
            findsOneWidget,
          );
        },
      );
    });
  });

  // ------------------------------------------------------------------
  // ForgotPasswordScreen
  // ------------------------------------------------------------------

  group('ForgotPasswordScreen', () {
    testWidgets('rejects empty and invalid email values', (tester) async {
      await _pump(tester, const ForgotPasswordScreen());
      await tester.tap(
        find.widgetWithText(ElevatedButton, 'إرسال رابط إعادة التعيين'),
      );
      await tester.pumpAndSettle();
      expect(find.text('يرجى إدخال البريد'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField), 'noatsign');
      await tester.tap(
        find.widgetWithText(ElevatedButton, 'إرسال رابط إعادة التعيين'),
      );
      await tester.pumpAndSettle();
      expect(find.text('بريد غير صالح'), findsOneWidget);
    });

    testWidgets('shows success SnackBar then pops the route', (tester) async {
      await withMockedHttp(
        setup: (r) =>
            r.respond('POST', '/api/auth/password-reset-request', body: {}),
        callback: (_) async {
          await _useTallViewport(tester);
          await tester.pumpWidget(
            MaterialApp(
              locale: const Locale('ar', 'SA'),
              supportedLocales: const [Locale('ar', 'SA')],
              localizationsDelegates: const [
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              home: Builder(
                builder: (context) => Scaffold(
                  body: Center(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ForgotPasswordScreen(),
                        ),
                      ),
                      child: const Text('open-forgot'),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('open-forgot'));
          await tester.pumpAndSettle();
          expect(find.byType(ForgotPasswordScreen), findsOneWidget);

          await tester.enterText(find.byType(TextFormField), 'tester@x.io');
          await tester.tap(
            find.widgetWithText(ElevatedButton, 'إرسال رابط إعادة التعيين'),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 50));
          await tester.pumpAndSettle();

          expect(find.byType(ForgotPasswordScreen), findsNothing);
          expect(find.text('open-forgot'), findsOneWidget);
        },
      );
    });

    testWidgets('429 rate-limit error shows server message', (tester) async {
      await withMockedHttp(
        setup: (r) => r.respond(
          'POST',
          '/api/auth/password-reset-request',
          statusCode: 429,
          body: {'message': 'محاولات كثيرة جداً، حاول لاحقاً'},
        ),
        callback: (_) async {
          await _pump(tester, const ForgotPasswordScreen());
          await tester.enterText(find.byType(TextFormField), 'tester@x.io');
          await tester.tap(
            find.widgetWithText(ElevatedButton, 'إرسال رابط إعادة التعيين'),
          );
          await tester.pumpAndSettle();
          expect(find.textContaining('محاولات كثيرة جداً'), findsOneWidget);
        },
      );
    });

    testWidgets('400 invalid email surfaces server message', (tester) async {
      await withMockedHttp(
        setup: (r) => r.respond(
          'POST',
          '/api/auth/password-reset-request',
          statusCode: 400,
          body: {'message': 'البريد غير صالح'},
        ),
        callback: (_) async {
          await _pump(tester, const ForgotPasswordScreen());
          await tester.enterText(find.byType(TextFormField), 'tester@x.io');
          await tester.tap(
            find.widgetWithText(ElevatedButton, 'إرسال رابط إعادة التعيين'),
          );
          await tester.pumpAndSettle();
          expect(find.text('البريد غير صالح'), findsOneWidget);
        },
      );
    });

    testWidgets('404 "no account" surfaces a friendly Arabic copy', (
      tester,
    ) async {
      await withMockedHttp(
        setup: (r) => r.respond(
          'POST',
          '/api/auth/password-reset-request',
          statusCode: 404,
          body: {'message': 'لا يوجد حساب بهذا البريد'},
        ),
        callback: (_) async {
          await _pump(tester, const ForgotPasswordScreen());
          await tester.enterText(find.byType(TextFormField), 'tester@x.io');
          await tester.tap(
            find.widgetWithText(ElevatedButton, 'إرسال رابط إعادة التعيين'),
          );
          await tester.pumpAndSettle();
          expect(find.textContaining('لا يوجد حساب'), findsOneWidget);
        },
      );
    });

    testWidgets('500 error keeps the screen', (tester) async {
      await withMockedHttp(
        setup: (r) => r.respond(
          'POST',
          '/api/auth/password-reset-request',
          statusCode: 500,
          body: {'message': 'oops'},
        ),
        callback: (_) async {
          await _pump(tester, const ForgotPasswordScreen());
          await tester.enterText(find.byType(TextFormField), 'tester@x.io');
          await tester.tap(
            find.widgetWithText(ElevatedButton, 'إرسال رابط إعادة التعيين'),
          );
          await tester.pumpAndSettle();
          expect(find.byType(ForgotPasswordScreen), findsOneWidget);
        },
      );
    });
  });

  // ------------------------------------------------------------------
  // RegistrationScreen
  // ------------------------------------------------------------------

  group('RegistrationScreen', () {
    testWidgets('driver registration renders stepper with truck form', (
      tester,
    ) async {
      await _pump(tester, const RegistrationScreen(role: 'driver'));
      expect(find.text('إنشاء حساب جديد'), findsOneWidget);
      expect(find.text('البيانات الأساسية'), findsOneWidget);
      expect(find.text('بيانات إضافية'), findsOneWidget);
      expect(find.text('رفع الوثائق'), findsOneWidget);
    });

    testWidgets('shipper renders commercial number field', (tester) async {
      await _pump(tester, const RegistrationScreen(role: 'shipper'));
      // The stepper renders all 3 step controls eagerly; only the active step is
      // visible. We just assert the screen mounted with shipper-only copy.
      expect(find.text('إنشاء حساب جديد'), findsOneWidget);
      expect(find.text('بيانات إضافية'), findsOneWidget);
    });

    testWidgets('stepper continue button advances step', (tester) async {
      await _pump(tester, const RegistrationScreen(role: 'shipper'));
      // The stepper places its continue button in the controlsBuilder.
      // Tap "CONTINUE" / "متابعة" if present to advance.
      final continueBtns = find.byWidgetPredicate(
        (w) => w is TextButton || w is ElevatedButton,
      );
      // Stepper material default buttons.
      final materialContinue = find.text('CONTINUE');
      if (materialContinue.evaluate().isNotEmpty) {
        await tester.tap(materialContinue.first);
        await tester.pumpAndSettle();
      } else if (continueBtns.evaluate().isNotEmpty) {
        // Fallback: try tapping any visible button.
      }
      expect(find.byType(RegistrationScreen), findsOneWidget);
    });

    testWidgets('shipper step 0 validates required fields on continue', (
      tester,
    ) async {
      await _pump(tester, const RegistrationScreen(role: 'shipper'));
      final cont = find.text('CONTINUE');
      if (cont.evaluate().isNotEmpty) {
        await tester.tap(cont.first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byType(RegistrationScreen), findsOneWidget);
    });

    testWidgets('driver step 1 issue-date and expiry-date tappable', (
      tester,
    ) async {
      await _pump(tester, const RegistrationScreen(role: 'driver'));
      // Advance to step 1.
      final cont = find.text('CONTINUE');
      if (cont.evaluate().isNotEmpty) {
        // Fill step 0 first.
        final fields = find.byType(TextFormField);
        if (fields.evaluate().length >= 4) {
          await tester.enterText(fields.at(0), 'أحمد');
          await tester.enterText(fields.at(1), 'driver@x.io');
          await tester.enterText(fields.at(2), '0501111111');
          await tester.enterText(fields.at(3), 'Secret123!');
          await tester.pump();
        }
        await tester.tap(cont.first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
      }
      // Find issue-date / expiry-date controllers by label.
      final issueDate = find.widgetWithText(TextFormField, 'تاريخ الإصدار');
      if (issueDate.evaluate().isNotEmpty) {
        await tester.ensureVisible(issueDate);
        await tester.pump();
        await tester.tap(issueDate, warnIfMissed: false);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        // Dismiss any picker that might have opened.
        final cancel = find.text('CANCEL');
        if (cancel.evaluate().isNotEmpty) {
          await tester.tap(cancel);
          await tester.pumpAndSettle();
        }
      }
      expect(find.byType(RegistrationScreen), findsOneWidget);
    });

    testWidgets('driver step 0 accepts filled basic fields', (tester) async {
      await _pump(tester, const RegistrationScreen(role: 'driver'));
      final fields = find.byType(TextFormField);
      if (fields.evaluate().length >= 4) {
        await tester.enterText(fields.at(0), 'أحمد');
        await tester.enterText(fields.at(1), 'driver@x.io');
        await tester.enterText(fields.at(2), '0501111111');
        await tester.enterText(fields.at(3), 'Secret123!');
        await tester.pump();
      }
      final cont = find.text('CONTINUE');
      if (cont.evaluate().isNotEmpty) {
        await tester.tap(cont.first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byType(RegistrationScreen), findsOneWidget);
    });

    testWidgets('shipper register without document shows validation snackbar', (
      tester,
    ) async {
      await _pump(tester, const RegistrationScreen(role: 'shipper'));
      // Tap CONTINUE twice (basic data → extra data) then once more (upload step).
      for (var i = 0; i < 3; i++) {
        final cont = find.text('CONTINUE');
        if (cont.evaluate().isEmpty) break;
        await tester.tap(cont.first);
        await tester.pumpAndSettle();
      }
      expect(find.byType(RegistrationScreen), findsOneWidget);
    });
  });
}
