import 'package:darbak/shipper_home.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/http_mock.dart';

Widget _wrap(Widget child) => MaterialApp(
      locale: const Locale('ar', 'SA'),
      supportedLocales: const [Locale('ar', 'SA')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(
        body: Directionality(textDirection: TextDirection.rtl, child: child),
      ),
    );

Future<void> _pump(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(_wrap(child));
  for (var i = 0; i < 14; i++) {
    await tester.pump(const Duration(milliseconds: 80));
  }
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ar', null);
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'user_id': 1,
      'user_role': 'shipper',
      'auth_token': 't',
    });
  });

  testWidgets('shows empty state when no notifications', (tester) async {
    await withMockedHttp(
      setup: (r) => r.respond('GET', '/api/notifications/user/1', body: {
        'notifications': [],
        'unread_count': 0,
      }),
      callback: (_) async {
        await _pump(tester, const ShipperNotificationsScreen());
        expect(find.text('لا توجد تنبيهات'), findsOneWidget);
      },
    );
  });

  testWidgets('renders contract notification with route substitution',
      (tester) async {
    await withMockedHttp(
      setup: (r) => r.respond('GET', '/api/notifications/user/1', body: {
        'notifications': [
          {
            'id': 1,
            'title': 'عقد إلكتروني',
            'message': 'تم إنشاء عقد رقم #9 للشحنة #15',
            'route_description': 'الرياض → جدة',
            'shipment_id': 15,
            'is_read': 0,
            'created_at': '2026-06-01T10:00:00Z',
          }
        ],
        'unread_count': 1,
      }),
      callback: (_) async {
        await _pump(tester, const ShipperNotificationsScreen());
        expect(find.text('عقد إلكتروني'), findsOneWidget);
        expect(find.textContaining('الرياض → جدة'), findsOneWidget);
      },
    );
  });

  testWidgets('missing user id shows error with retry', (tester) async {
    SharedPreferences.setMockInitialValues({'auth_token': 't'});
    await _pump(tester, const ShipperNotificationsScreen());
    expect(find.text('لم يتم العثور على المستخدم'), findsOneWidget);
    expect(find.text('إعادة المحاولة'), findsOneWidget);
  });
}
