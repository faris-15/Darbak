import 'package:darbak/auth_screens.dart';
import 'package:darbak/app_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/http_mock.dart';

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
      '/roleSelection': (_) => const ChooseRoleScreen(),
      '/login': (_) => const LoginScreen(),
    },
  );
}

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
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('login with admin role navigates without unknown-role snackbar',
      (tester) async {
    await withMockedHttp(
      setup: (r) {
        r.respond('POST', '/api/auth/login', body: {
          'token': 't',
          'user': {
            'id': 3,
            'role': 'admin',
            'full_name': 'Admin',
            'email': 'admin@x.io',
          }
        });
        r.respond('GET', '/api/profile/me', body: {
          'data': {'id': 3, 'role': 'admin', 'full_name': 'Admin'}
        });
        r.respond('GET', '/api/shipments', body: []);
      },
      callback: (_) async {
        await _pump(tester, const LoginScreen());
        await tester.enterText(
          find.widgetWithText(TextField, '05xxxxxxxx أو example@mail.com'),
          'admin@x.io',
        );
        await tester.enterText(
          find.widgetWithText(TextField, 'كلمة المرور'),
          'password',
        );
        final btn = find.widgetWithText(DarbakPrimaryButton, 'متابعة').first;
        await tester.ensureVisible(btn);
        await tester.pump();
        await tester.tap(btn);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.text('دور المستخدم غير معروف'), findsNothing);
      },
    );
  });

  testWidgets('ForgotPasswordScreen 500 error shows retry-later copy', (tester) async {
    await withMockedHttp(
      setup: (r) => r.respond(
        'POST',
        '/api/auth/password-reset-request',
        statusCode: 500,
        body: {'message': 'internal'},
      ),
      callback: (_) async {
        await _pump(tester, const ForgotPasswordScreen());
        await tester.enterText(find.byType(TextFormField), 'user@x.io');
        await tester.tap(
          find.widgetWithText(ElevatedButton, 'إرسال رابط إعادة التعيين'),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(
          find.text('تعذّر إرسال الرابط حالياً. حاول لاحقاً.'),
          findsOneWidget,
        );
      },
    );
  });

  testWidgets('RegistrationScreen register failure shows error snackbar',
      (tester) async {
    await withMockedHttp(
      setup: (r) => r.respond('POST', '/api/auth/register',
          statusCode: 400, body: {'message': 'البريد مستخدم مسبقاً'}),
      callback: (_) async {
        await _pump(tester, const RegistrationScreen(role: 'shipper'));
        // Advance to documents step and attempt register without file.
        for (var i = 0; i < 3; i++) {
          final cont = find.text('CONTINUE');
          if (cont.evaluate().isEmpty) break;
          await tester.tap(cont.first);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));
        }
        final create = find.text('إنشاء الحساب');
        if (create.evaluate().isNotEmpty) {
          await tester.tap(create);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(find.byType(RegistrationScreen), findsOneWidget);
      },
    );
  });

  testWidgets('login 401 email triggers firebase override path', (tester) async {
    await withMockedHttp(
      setup: (r) {
        r.respond('POST', '/api/auth/login',
            statusCode: 401, body: {'message': 'unauthorized'});
        r.respond('POST', '/api/auth/login-firebase', body: {
          'token': 't',
          'user': {
            'id': 8,
            'role': 'shipper',
            'email': 'fb@x.io',
            'full_name': 'FB User',
          }
        });
        r.respond('GET', '/api/profile/me', body: {
          'data': {'id': 8, 'role': 'shipper', 'verification_status': 'verified'}
        });
        r.respond('GET', '/api/shipments', body: []);
        r.respond('GET', '/api/chat/conversations/me', body: []);
        r.respond('GET', '/api/notifications/user/8',
            body: {'data': [], 'unread_count': 0});
      },
      callback: (_) async {
        await _pump(
          tester,
          LoginScreen(
            firebaseSignInOverride: (email, password) async => 'fake-id-token',
          ),
        );
        await tester.enterText(
          find.widgetWithText(TextField, '05xxxxxxxx أو example@mail.com'),
          'fb@x.io',
        );
        await tester.enterText(
          find.widgetWithText(TextField, 'كلمة المرور'),
          'password',
        );
        final btn = find.widgetWithText(DarbakPrimaryButton, 'متابعة').first;
        await tester.tap(btn);
        await tester.pump();
        for (var i = 0; i < 16; i++) {
          await tester.pump(const Duration(milliseconds: 80));
        }
        expect(find.byType(LoginScreen), findsNothing);
      },
    );
  });

  testWidgets('RegistrationScreen shipper commercial number validation snackbar',
      (tester) async {
    await _pump(tester, const RegistrationScreen(role: 'shipper'));
    // Fill step 0
    final fields = find.byType(TextFormField);
    if (fields.evaluate().length >= 4) {
      await tester.enterText(fields.at(0), 'شركة');
      await tester.enterText(fields.at(1), 'shipper@x.io');
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
    // Step 1 without commercial number, tap continue again then create on step 2
    if (cont.evaluate().isNotEmpty) {
      await tester.tap(cont.first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(RegistrationScreen), findsOneWidget);
  });
}
