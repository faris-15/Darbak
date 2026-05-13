import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:darbak/api_service.dart';
import 'package:darbak/app_theme.dart';
import 'package:darbak/auth_screens.dart';
import 'package:darbak/shipment_bids_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../unit/api_service_test.mocks.dart';

http.Response _utf8Body(String body, int statusCode) {
  return http.Response.bytes(utf8.encode(body), statusCode);
}

void main() {
  group('LoginScreen', () {
    testWidgets('shows identifier and password fields and primary button', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: DarbakTheme.lightTheme,
          home: const LoginScreen(),
        ),
      );

      expect(find.text('تسجيل الدخول'), findsWidgets);
      expect(find.textContaining('رقم الجوال'), findsOneWidget);
      expect(find.text('كلمة المرور'), findsOneWidget);
      expect(find.text('متابعة'), findsOneWidget);
    });

    testWidgets('empty submit shows error feedback via SnackBar', (tester) async {
      final mockClient = MockClient();
      ApiService.setHttpClientForTests(mockClient);
      addTearDown(ApiService.resetHttpClientForTests);

      when(
        mockClient.post(
          Uri.parse('http://10.0.2.2:5000/api/auth/login'),
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        ),
      ).thenAnswer((_) async => _utf8Body('{"message":"بيانات ناقصة"}', 400));

      await tester.pumpWidget(
        MaterialApp(
          theme: DarbakTheme.lightTheme,
          home: const LoginScreen(),
        ),
      );

      await tester.tap(find.text('متابعة'));
      await tester.pumpAndSettle();

      expect(find.textContaining('بيانات ناقصة'), findsOneWidget);
    });

    testWidgets('shows CircularProgressIndicator while login request in flight', (tester) async {
      final mockClient = MockClient();
      ApiService.setHttpClientForTests(mockClient);
      addTearDown(ApiService.resetHttpClientForTests);

      final completer = Completer<http.Response>();
      when(
        mockClient.post(
          Uri.parse('http://10.0.2.2:5000/api/auth/login'),
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        ),
      ).thenAnswer((_) => completer.future);

      await tester.pumpWidget(
        MaterialApp(
          theme: DarbakTheme.lightTheme,
          home: const LoginScreen(),
        ),
      );

      await tester.tap(find.text('متابعة'));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      completer.complete(_utf8Body('{"message":"فشل"}', 401));
      await tester.pumpAndSettle();
      expect(find.textContaining('فشل'), findsOneWidget);
    });

    testWidgets('invalid email shows backend validation text', (tester) async {
      final mockClient = MockClient();
      ApiService.setHttpClientForTests(mockClient);
      addTearDown(ApiService.resetHttpClientForTests);

      when(
        mockClient.post(
          Uri.parse('http://10.0.2.2:5000/api/auth/login'),
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        ),
      ).thenAnswer((_) async => _utf8Body('{"message":"صيغة البريد الإلكتروني غير صحيحة"}', 400));

      await tester.pumpWidget(
        MaterialApp(
          theme: DarbakTheme.lightTheme,
          home: const LoginScreen(),
        ),
      );

      await tester.enterText(
        find.byType(TextField).first,
        'invalid-email-without-at',
      );
      await tester.enterText(
        find.byType(TextField).at(1),
        '123456',
      );
      await tester.tap(find.text('متابعة'));
      await tester.pumpAndSettle();

      expect(find.textContaining('صيغة البريد الإلكتروني غير صحيحة'), findsOneWidget);
    });

    testWidgets('short password shows backend validation text', (tester) async {
      final mockClient = MockClient();
      ApiService.setHttpClientForTests(mockClient);
      addTearDown(ApiService.resetHttpClientForTests);

      when(
        mockClient.post(
          Uri.parse('http://10.0.2.2:5000/api/auth/login'),
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        ),
      ).thenAnswer((_) async => _utf8Body('{"message":"كلمة المرور قصيرة جدا"}', 400));

      await tester.pumpWidget(
        MaterialApp(
          theme: DarbakTheme.lightTheme,
          home: const LoginScreen(),
        ),
      );

      await tester.enterText(find.byType(TextField).first, 'user@example.com');
      await tester.enterText(find.byType(TextField).at(1), '123');
      await tester.tap(find.text('متابعة'));
      await tester.pumpAndSettle();

      expect(find.textContaining('كلمة المرور قصيرة جدا'), findsOneWidget);
    });

    testWidgets('submitting empty form shows validation feedback from server', (tester) async {
      final mockClient = MockClient();
      ApiService.setHttpClientForTests(mockClient);
      addTearDown(ApiService.resetHttpClientForTests);

      when(
        mockClient.post(
          Uri.parse('http://10.0.2.2:5000/api/auth/login'),
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        ),
      ).thenAnswer((_) async => _utf8Body('{"message":"الرجاء تعبئة جميع الحقول"}', 400));

      await tester.pumpWidget(
        MaterialApp(
          theme: DarbakTheme.lightTheme,
          home: const LoginScreen(),
        ),
      );

      await tester.tap(find.text('متابعة'));
      await tester.pumpAndSettle();
      expect(find.textContaining('الرجاء تعبئة جميع الحقول'), findsOneWidget);
    });

    testWidgets('tapping login multiple times does not trigger concurrent requests', (tester) async {
      final mockClient = MockClient();
      ApiService.setHttpClientForTests(mockClient);
      addTearDown(ApiService.resetHttpClientForTests);

      final completer = Completer<http.Response>();
      when(
        mockClient.post(
          Uri.parse('http://10.0.2.2:5000/api/auth/login'),
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        ),
      ).thenAnswer((_) => completer.future);

      await tester.pumpWidget(
        MaterialApp(
          theme: DarbakTheme.lightTheme,
          home: const LoginScreen(),
        ),
      );

      await tester.enterText(find.byType(TextField).first, 'user@example.com');
      await tester.enterText(find.byType(TextField).at(1), '123456');
      await tester.tap(find.text('متابعة'));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('متابعة'), findsNothing);
      verify(
        mockClient.post(
          Uri.parse('http://10.0.2.2:5000/api/auth/login'),
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        ),
      ).called(1);

      completer.complete(_utf8Body('{"message":"فشل"}', 401));
      await tester.pumpAndSettle();
    });

    testWidgets('loading indicator disappears after failed request', (tester) async {
      final mockClient = MockClient();
      ApiService.setHttpClientForTests(mockClient);
      addTearDown(ApiService.resetHttpClientForTests);

      final completer = Completer<http.Response>();
      when(
        mockClient.post(
          Uri.parse('http://10.0.2.2:5000/api/auth/login'),
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        ),
      ).thenAnswer((_) => completer.future);

      await tester.pumpWidget(
        MaterialApp(
          theme: DarbakTheme.lightTheme,
          home: const LoginScreen(),
        ),
      );

      await tester.tap(find.text('متابعة'));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      completer.complete(_utf8Body('{"message":"فشل"}', 401));
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('متابعة'), findsOneWidget);
    });

    testWidgets('valid email and valid password submits successfully', (tester) async {
      final mockClient = MockClient();
      ApiService.setHttpClientForTests(mockClient);
      addTearDown(ApiService.resetHttpClientForTests);

      when(
        mockClient.post(
          Uri.parse('http://10.0.2.2:5000/api/auth/login'),
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        ),
      ).thenAnswer(
        (_) async => _utf8Body(
          '{"user":{"id":1,"role":"shipper","email":"user@example.com","full_name":"User"},"token":"abc"}',
          200,
        ),
      );

      await tester.pumpWidget(MaterialApp(theme: DarbakTheme.lightTheme, home: const LoginScreen()));
      await tester.enterText(find.byType(TextField).first, 'user@example.com');
      await tester.enterText(find.byType(TextField).at(1), '123456');
      await tester.tap(find.text('متابعة'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      verify(
        mockClient.post(
          Uri.parse('http://10.0.2.2:5000/api/auth/login'),
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        ),
      ).called(1);
    });

    testWidgets('empty email shows error message', (tester) async {
      final mockClient = MockClient();
      ApiService.setHttpClientForTests(mockClient);
      addTearDown(ApiService.resetHttpClientForTests);
      when(
        mockClient.post(
          Uri.parse('http://10.0.2.2:5000/api/auth/login'),
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        ),
      ).thenAnswer((_) async => _utf8Body('{"message":"البريد الإلكتروني مطلوب"}', 400));

      await tester.pumpWidget(MaterialApp(theme: DarbakTheme.lightTheme, home: const LoginScreen()));
      await tester.enterText(find.byType(TextField).at(1), '123456');
      await tester.tap(find.text('متابعة'));
      await tester.pumpAndSettle();
      expect(find.textContaining('البريد الإلكتروني مطلوب'), findsOneWidget);
    });

    testWidgets('empty password shows error message', (tester) async {
      final mockClient = MockClient();
      ApiService.setHttpClientForTests(mockClient);
      addTearDown(ApiService.resetHttpClientForTests);
      when(
        mockClient.post(
          Uri.parse('http://10.0.2.2:5000/api/auth/login'),
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        ),
      ).thenAnswer((_) async => _utf8Body('{"message":"كلمة المرور مطلوبة"}', 400));

      await tester.pumpWidget(MaterialApp(theme: DarbakTheme.lightTheme, home: const LoginScreen()));
      await tester.enterText(find.byType(TextField).first, 'user@example.com');
      await tester.tap(find.text('متابعة'));
      await tester.pumpAndSettle();
      expect(find.textContaining('كلمة المرور مطلوبة'), findsOneWidget);
    });

    testWidgets('both empty shows combined errors message', (tester) async {
      final mockClient = MockClient();
      ApiService.setHttpClientForTests(mockClient);
      addTearDown(ApiService.resetHttpClientForTests);
      when(
        mockClient.post(
          Uri.parse('http://10.0.2.2:5000/api/auth/login'),
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        ),
      ).thenAnswer((_) async => _utf8Body('{"message":"البريد وكلمة المرور مطلوبان"}', 400));

      await tester.pumpWidget(MaterialApp(theme: DarbakTheme.lightTheme, home: const LoginScreen()));
      await tester.tap(find.text('متابعة'));
      await tester.pumpAndSettle();
      expect(find.textContaining('البريد وكلمة المرور مطلوبان'), findsOneWidget);
    });

    testWidgets('email with spaces shows format error', (tester) async {
      final mockClient = MockClient();
      ApiService.setHttpClientForTests(mockClient);
      addTearDown(ApiService.resetHttpClientForTests);
      when(
        mockClient.post(
          Uri.parse('http://10.0.2.2:5000/api/auth/login'),
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        ),
      ).thenAnswer((_) async => _utf8Body('{"message":"صيغة البريد الإلكتروني غير صحيحة"}', 400));

      await tester.pumpWidget(MaterialApp(theme: DarbakTheme.lightTheme, home: const LoginScreen()));
      await tester.enterText(find.byType(TextField).first, 'test @gmail.com');
      await tester.enterText(find.byType(TextField).at(1), '123456');
      await tester.tap(find.text('متابعة'));
      await tester.pumpAndSettle();
      expect(find.textContaining('صيغة البريد الإلكتروني غير صحيحة'), findsOneWidget);
    });

    testWidgets('password exactly 5 chars shows min length error', (tester) async {
      final mockClient = MockClient();
      ApiService.setHttpClientForTests(mockClient);
      addTearDown(ApiService.resetHttpClientForTests);
      when(
        mockClient.post(
          Uri.parse('http://10.0.2.2:5000/api/auth/login'),
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        ),
      ).thenAnswer((_) async => _utf8Body('{"message":"كلمة المرور قصيرة جدا"}', 400));

      await tester.pumpWidget(MaterialApp(theme: DarbakTheme.lightTheme, home: const LoginScreen()));
      await tester.enterText(find.byType(TextField).first, 'user@gmail.com');
      await tester.enterText(find.byType(TextField).at(1), '12345');
      await tester.tap(find.text('متابعة'));
      await tester.pumpAndSettle();
      expect(find.textContaining('كلمة المرور قصيرة جدا'), findsOneWidget);
    });

    testWidgets('password exactly 6 chars submits successfully', (tester) async {
      final mockClient = MockClient();
      ApiService.setHttpClientForTests(mockClient);
      addTearDown(ApiService.resetHttpClientForTests);
      when(
        mockClient.post(
          Uri.parse('http://10.0.2.2:5000/api/auth/login'),
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        ),
      ).thenAnswer(
        (_) async => _utf8Body(
          '{"user":{"id":2,"role":"shipper","email":"user@gmail.com","full_name":"User"},"token":"t"}',
          200,
        ),
      );

      await tester.pumpWidget(MaterialApp(theme: DarbakTheme.lightTheme, home: const LoginScreen()));
      await tester.enterText(find.byType(TextField).first, 'user@gmail.com');
      await tester.enterText(find.byType(TextField).at(1), '123456');
      await tester.tap(find.text('متابعة'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('متابعة'), findsNothing);
    });

    testWidgets('uppercase email TEST@gmail.com is accepted', (tester) async {
      final mockClient = MockClient();
      ApiService.setHttpClientForTests(mockClient);
      addTearDown(ApiService.resetHttpClientForTests);
      when(
        mockClient.post(
          Uri.parse('http://10.0.2.2:5000/api/auth/login'),
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        ),
      ).thenAnswer(
        (_) async => _utf8Body(
          '{"user":{"id":3,"role":"shipper","email":"TEST@gmail.com","full_name":"User"},"token":"t"}',
          200,
        ),
      );

      await tester.pumpWidget(MaterialApp(theme: DarbakTheme.lightTheme, home: const LoginScreen()));
      await tester.enterText(find.byType(TextField).first, 'TEST@gmail.com');
      await tester.enterText(find.byType(TextField).at(1), '123456');
      await tester.tap(find.text('متابعة'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      verify(
        mockClient.post(
          Uri.parse('http://10.0.2.2:5000/api/auth/login'),
          headers: anyNamed('headers'),
          body: argThat(contains('TEST@gmail.com'), named: 'body'),
        ),
      ).called(1);
    });

    testWidgets('SQL injection in email is rejected safely', (tester) async {
      final mockClient = MockClient();
      ApiService.setHttpClientForTests(mockClient);
      addTearDown(ApiService.resetHttpClientForTests);
      when(
        mockClient.post(
          Uri.parse('http://10.0.2.2:5000/api/auth/login'),
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        ),
      ).thenAnswer((_) async => _utf8Body('{"message":"صيغة البريد الإلكتروني غير صحيحة"}', 400));

      await tester.pumpWidget(MaterialApp(theme: DarbakTheme.lightTheme, home: const LoginScreen()));
      await tester.enterText(find.byType(TextField).first, "' OR 1=1 --@gmail.com");
      await tester.enterText(find.byType(TextField).at(1), '123456');
      await tester.tap(find.text('متابعة'));
      await tester.pumpAndSettle();
      expect(find.textContaining('صيغة البريد الإلكتروني غير صحيحة'), findsOneWidget);
    });

    testWidgets('200 success navigates away from login screen', (tester) async {
      final mockClient = MockClient();
      ApiService.setHttpClientForTests(mockClient);
      addTearDown(ApiService.resetHttpClientForTests);

      when(
        mockClient.post(
          Uri.parse('http://10.0.2.2:5000/api/auth/login'),
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        ),
      ).thenAnswer(
        (_) async => _utf8Body(
          '{"user":{"id":7,"role":"shipper","email":"ok@x.com","full_name":"U"},"token":"tok"}',
          200,
        ),
      );

      await tester.pumpWidget(MaterialApp(theme: DarbakTheme.lightTheme, home: const LoginScreen()));
      await tester.enterText(find.byType(TextField).first, 'ok@x.com');
      await tester.enterText(find.byType(TextField).at(1), '123456');
      await tester.tap(find.text('متابعة'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('متابعة'), findsNothing);
    });

    testWidgets('401 wrong credentials shows بيانات خاطئة message', (tester) async {
      final mockClient = MockClient();
      ApiService.setHttpClientForTests(mockClient);
      addTearDown(ApiService.resetHttpClientForTests);
      when(
        mockClient.post(
          Uri.parse('http://10.0.2.2:5000/api/auth/login'),
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        ),
      ).thenAnswer((_) async => _utf8Body('{"message":"بيانات خاطئة"}', 401));

      await tester.pumpWidget(MaterialApp(theme: DarbakTheme.lightTheme, home: const LoginScreen()));
      await tester.enterText(find.byType(TextField).first, 'user@example.com');
      await tester.enterText(find.byType(TextField).at(1), 'badbad');
      await tester.tap(find.text('متابعة'));
      await tester.pumpAndSettle();
      expect(find.textContaining('بيانات خاطئة'), findsOneWidget);
    });

    testWidgets('404 user not found shows error message', (tester) async {
      final mockClient = MockClient();
      ApiService.setHttpClientForTests(mockClient);
      addTearDown(ApiService.resetHttpClientForTests);
      when(
        mockClient.post(
          Uri.parse('http://10.0.2.2:5000/api/auth/login'),
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        ),
      ).thenAnswer((_) async => _utf8Body('{"message":"المستخدم غير موجود"}', 404));

      await tester.pumpWidget(MaterialApp(theme: DarbakTheme.lightTheme, home: const LoginScreen()));
      await tester.enterText(find.byType(TextField).first, 'missing@example.com');
      await tester.enterText(find.byType(TextField).at(1), '123456');
      await tester.tap(find.text('متابعة'));
      await tester.pumpAndSettle();
      expect(find.textContaining('المستخدم غير موجود'), findsOneWidget);
    });

    testWidgets('500 server error shows خطأ في السيرفر message', (tester) async {
      final mockClient = MockClient();
      ApiService.setHttpClientForTests(mockClient);
      addTearDown(ApiService.resetHttpClientForTests);
      when(
        mockClient.post(
          Uri.parse('http://10.0.2.2:5000/api/auth/login'),
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        ),
      ).thenAnswer((_) async => _utf8Body('{"message":"خطأ في السيرفر"}', 500));

      await tester.pumpWidget(MaterialApp(theme: DarbakTheme.lightTheme, home: const LoginScreen()));
      await tester.enterText(find.byType(TextField).first, 'user@example.com');
      await tester.enterText(find.byType(TextField).at(1), '123456');
      await tester.tap(find.text('متابعة'));
      await tester.pumpAndSettle();
      expect(find.textContaining('خطأ في السيرفر'), findsOneWidget);
    });

    testWidgets('SocketException shows connectivity error', (tester) async {
      final mockClient = MockClient();
      ApiService.setHttpClientForTests(mockClient);
      addTearDown(ApiService.resetHttpClientForTests);
      when(
        mockClient.post(
          Uri.parse('http://10.0.2.2:5000/api/auth/login'),
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        ),
      ).thenThrow(const SocketException('Failed host lookup'));

      await tester.pumpWidget(MaterialApp(theme: DarbakTheme.lightTheme, home: const LoginScreen()));
      await tester.tap(find.text('متابعة'));
      await tester.pumpAndSettle();
      expect(find.textContaining('تعذر الاتصال بالخادم'), findsOneWidget);
    });

    testWidgets('TimeoutException shows timeout error message', (tester) async {
      final mockClient = MockClient();
      ApiService.setHttpClientForTests(mockClient);
      addTearDown(ApiService.resetHttpClientForTests);
      when(
        mockClient.post(
          Uri.parse('http://10.0.2.2:5000/api/auth/login'),
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        ),
      ).thenThrow(TimeoutException('request timeout'));

      await tester.pumpWidget(MaterialApp(theme: DarbakTheme.lightTheme, home: const LoginScreen()));
      await tester.tap(find.text('متابعة'));
      await tester.pumpAndSettle();
      expect(find.textContaining('TimeoutException'), findsOneWidget);
    });

    testWidgets('Saudi phone number 05XXXXXXXX accepted as valid identifier', (tester) async {
      final mockClient = MockClient();
      ApiService.setHttpClientForTests(mockClient);
      addTearDown(ApiService.resetHttpClientForTests);
      when(
        mockClient.post(
          Uri.parse('http://10.0.2.2:5000/api/auth/login'),
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        ),
      ).thenAnswer(
        (_) async => _utf8Body(
          '{"user":{"id":8,"role":"shipper","email":"","full_name":"U"},"token":"tok"}',
          200,
        ),
      );

      await tester.pumpWidget(MaterialApp(theme: DarbakTheme.lightTheme, home: const LoginScreen()));
      await tester.enterText(find.byType(TextField).first, '0512345678');
      await tester.enterText(find.byType(TextField).at(1), '123456');
      await tester.tap(find.text('متابعة'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      verify(
        mockClient.post(
          Uri.parse('http://10.0.2.2:5000/api/auth/login'),
          headers: anyNamed('headers'),
          body: argThat(contains('0512345678'), named: 'body'),
        ),
      ).called(1);
    });
  });

  group('ShipmentBidsDetailScreen bid card', () {
    testWidgets('shows driver name, amount, days, and rating', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final mockClient = MockClient();
      ApiService.setHttpClientForTests(mockClient);
      addTearDown(ApiService.resetHttpClientForTests);

      when(
        mockClient.get(
          Uri.parse('http://10.0.2.2:5000/api/bids/shipment/42'),
          headers: anyNamed('headers'),
        ),
      ).thenAnswer(
        (_) async => _utf8Body(
          jsonEncode([
            {
              'id': 1,
              'shipment_id': 42,
              'driver_id': 9,
              'bid_amount': 2500.5,
              'estimated_days': 11,
              'bid_status': 'pending',
              'driver_name': 'سائق أحمد',
              'driver_rating': 4.25,
              'rating_count': 6,
            },
          ]),
          200,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: DarbakTheme.lightTheme,
          home: const ShipmentBidsDetailScreen(
            shipmentId: 42,
            shipmentTitle: 'شحنة تجريبية',
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('سائق أحمد'), findsOneWidget);
      expect(find.textContaining('2500.50'), findsWidgets);
      expect(find.text('11 أيام'), findsOneWidget);
      expect(find.textContaining('4.3'), findsWidgets);
      expect(find.textContaining('تقييم'), findsOneWidget);
    });

    testWidgets('loading state shows CircularProgressIndicator', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final mockClient = MockClient();
      ApiService.setHttpClientForTests(mockClient);
      addTearDown(ApiService.resetHttpClientForTests);

      final done = Completer<http.Response>();
      when(
        mockClient.get(
          Uri.parse('http://10.0.2.2:5000/api/bids/shipment/1'),
          headers: anyNamed('headers'),
        ),
      ).thenAnswer((_) => done.future);

      await tester.pumpWidget(
        MaterialApp(
          theme: DarbakTheme.lightTheme,
          home: const ShipmentBidsDetailScreen(
            shipmentId: 1,
            shipmentTitle: 'x',
          ),
        ),
      );

      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      done.complete(_utf8Body('[]', 200));
      await tester.pumpAndSettle();
    });

    testWidgets('empty state shown when no bids exist', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final mockClient = MockClient();
      ApiService.setHttpClientForTests(mockClient);
      addTearDown(ApiService.resetHttpClientForTests);

      when(
        mockClient.get(
          Uri.parse('http://10.0.2.2:5000/api/bids/shipment/77'),
          headers: anyNamed('headers'),
        ),
      ).thenAnswer((_) async => _utf8Body('[]', 200));

      await tester.pumpWidget(
        MaterialApp(
          theme: DarbakTheme.lightTheme,
          home: const ShipmentBidsDetailScreen(
            shipmentId: 77,
            shipmentTitle: 'بدون عروض',
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('لا توجد عروض حتى الآن'), findsOneWidget);
      expect(find.byIcon(Icons.inbox_outlined), findsOneWidget);
    });

    testWidgets('error state shown then retry works', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final mockClient = MockClient();
      ApiService.setHttpClientForTests(mockClient);
      addTearDown(ApiService.resetHttpClientForTests);

      when(
        mockClient.get(
          Uri.parse('http://10.0.2.2:5000/api/bids/shipment/88'),
          headers: anyNamed('headers'),
        ),
      ).thenAnswer((_) async => _utf8Body('{"message":"boom"}', 500));

      await tester.pumpWidget(
        MaterialApp(
          theme: DarbakTheme.lightTheme,
          home: const ShipmentBidsDetailScreen(
            shipmentId: 88,
            shipmentTitle: 'إعادة المحاولة',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('خطأ في تحميل العروض'), findsOneWidget);
      expect(find.text('إعادة محاولة'), findsOneWidget);

      when(
        mockClient.get(
          Uri.parse('http://10.0.2.2:5000/api/bids/shipment/88'),
          headers: anyNamed('headers'),
        ),
      ).thenAnswer((_) async => _utf8Body('[]', 200));

      await tester.tap(find.text('إعادة محاولة'));
      await tester.pumpAndSettle();
      expect(find.text('لا توجد عروض حتى الآن'), findsOneWidget);
    });

    testWidgets('pending bid shows accept action button', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final mockClient = MockClient();
      ApiService.setHttpClientForTests(mockClient);
      addTearDown(ApiService.resetHttpClientForTests);

      when(
        mockClient.get(
          Uri.parse('http://10.0.2.2:5000/api/bids/shipment/99'),
          headers: anyNamed('headers'),
        ),
      ).thenAnswer(
        (_) async => _utf8Body(
          jsonEncode([
            {
              'id': 5,
              'shipment_id': 99,
              'driver_id': 2,
              'bid_amount': 100,
              'estimated_days': 2,
              'bid_status': 'pending',
              'driver_name': 'Driver',
              'driver_rating': 3.5,
              'rating_count': 3,
            },
          ]),
          200,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: DarbakTheme.lightTheme,
          home: const ShipmentBidsDetailScreen(shipmentId: 99, shipmentTitle: 'x'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('قبول العرض'), findsOneWidget);
    });

    testWidgets('accept button enters loading state while request in flight', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final mockClient = MockClient();
      ApiService.setHttpClientForTests(mockClient);
      addTearDown(ApiService.resetHttpClientForTests);

      when(
        mockClient.get(
          Uri.parse('http://10.0.2.2:5000/api/bids/shipment/66'),
          headers: anyNamed('headers'),
        ),
      ).thenAnswer(
        (_) async => _utf8Body(
          jsonEncode([
            {
              'id': 10,
              'shipment_id': 66,
              'driver_id': 8,
              'bid_amount': 200,
              'estimated_days': 6,
              'bid_status': 'pending',
              'driver_name': 'Driver 1',
              'driver_rating': 4.0,
              'rating_count': 12,
            },
          ]),
          200,
        ),
      );

      final acceptCompleter = Completer<http.Response>();
      when(
        mockClient.post(
          Uri.parse('http://10.0.2.2:5000/api/bids/10/accept'),
          headers: anyNamed('headers'),
        ),
      ).thenAnswer((_) => acceptCompleter.future);

      await tester.pumpWidget(
        MaterialApp(
          theme: DarbakTheme.lightTheme,
          home: const ShipmentBidsDetailScreen(shipmentId: 66, shipmentTitle: 'x'),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('قبول العرض'));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      acceptCompleter.complete(_utf8Body('{}', 200));
      await tester.pumpAndSettle();
      expect(find.textContaining('تم قبول العرض بنجاح'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
    });
  });

  group('RegistrationScreen document upload step', () {
    testWidgets('shipper flow shows upload_file control on documents step', (tester) async {
      addTearDown(() => tester.view.resetPhysicalSize());
      addTearDown(() => tester.view.resetDevicePixelRatio());
      tester.view.physicalSize = const Size(1080, 3200);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        MaterialApp(
          theme: DarbakTheme.lightTheme,
          home: const RegistrationScreen(role: 'shipper'),
        ),
      );

      final continueLabel = MaterialLocalizations.of(
        tester.element(find.byType(Stepper)),
      ).continueButtonLabel;

      await tester.tap(find.text(continueLabel).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text(continueLabel).first, warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.upload_file), findsOneWidget);
      expect(find.text('رفع السجل التجاري'), findsOneWidget);
    });
  });
}
