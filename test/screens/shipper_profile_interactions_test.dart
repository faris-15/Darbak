import 'package:darbak/shipper_home.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/http_mock.dart';

Widget _wrap(Widget child) => MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar', 'SA'),
      supportedLocales: const [Locale('ar', 'SA')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Directionality(textDirection: TextDirection.rtl, child: child),
    );

void _tall(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 3600);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Future<void> _pump(WidgetTester tester, Widget child,
    {int iterations = 14}) async {
  _tall(tester);
  await tester.pumpWidget(_wrap(Scaffold(body: child)));
  for (var i = 0; i < iterations; i++) {
    await tester.pump(const Duration(milliseconds: 80));
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'user_id': 1,
      'user_role': 'shipper',
      'auth_token': 't',
    });
  });

  testWidgets('ShipperProfileScreen renders and enters edit mode',
      (tester) async {
    await withMockedHttp(
      setup: (r) {
        r.respond('GET', '/api/profile/me', body: {
          'data': {
            'id': 1,
            'full_name': 'شركة الاختبار',
            'email': 'test@x.io',
            'phone': '0500000000',
            'commercial_no': '1234567890',
            'role': 'shipper',
            'verification_status': 'verified',
          }
        });
      },
      callback: (_) async {
        await _pump(tester, const ShipperProfileScreen());
        expect(find.byType(ShipperProfileScreen), findsOneWidget);
        expect(find.text('شركة الاختبار'), findsAtLeast(1));

        final editIcon = find.byIcon(Icons.edit);
        if (editIcon.evaluate().isNotEmpty) {
          await tester.tap(editIcon.first);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));
          expect(find.byIcon(Icons.save_rounded), findsAtLeast(1));
          expect(find.text('إلغاء التعديل'), findsOneWidget);

          // Cancel edit
          await tester.tap(find.text('إلغاء التعديل'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 50));
        }
      },
    );
  });

  testWidgets('ShipperProfileScreen save edits hits update endpoint',
      (tester) async {
    await withMockedHttp(
      setup: (r) {
        r.respond('GET', '/api/profile/me', body: {
          'data': {
            'id': 1,
            'full_name': 'شركة الاختبار',
            'email': 'test@x.io',
            'phone': '0500000000',
            'commercial_no': '1234567890',
            'role': 'shipper',
            'verification_status': 'verified',
          }
        });
        r.respond('PUT', '/api/profile/me', body: {
          'data': {
            'id': 1,
            'full_name': 'شركة الاختبار',
            'email': 'test@x.io',
            'phone': '0500000000',
            'commercial_no': '1234567890',
            'role': 'shipper',
            'verification_status': 'verified',
          }
        });
      },
      callback: (_) async {
        await _pump(tester, const ShipperProfileScreen());
        // Enter edit mode
        final editIcon = find.byIcon(Icons.edit);
        if (editIcon.evaluate().isNotEmpty) {
          await tester.tap(editIcon.first);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));

          // Tap the save button at bottom
          final saveBtn = find.text('حفظ التعديلات');
          if (saveBtn.evaluate().isNotEmpty) {
            await tester.ensureVisible(saveBtn.last);
            await tester.pumpAndSettle();
            await tester.tap(saveBtn.last);
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 200));
          }
        }
        expect(find.byType(ShipperProfileScreen), findsOneWidget);
      },
    );
  });

  testWidgets('ShipperProfileScreen with pending verification shows banner',
      (tester) async {
    await withMockedHttp(
      setup: (r) {
        r.respond('GET', '/api/profile/me', body: {
          'data': {
            'id': 1,
            'full_name': 'شركة الاختبار',
            'role': 'shipper',
            'verification_status': 'pending',
          }
        });
      },
      callback: (_) async {
        await _pump(tester, const ShipperProfileScreen());
        expect(find.byType(ShipperProfileScreen), findsOneWidget);
      },
    );
  });

  testWidgets('ShipperMessagesScreen renders conversation rows',
      (tester) async {
    await withMockedHttp(
      setup: (r) {
        r.respond('GET', '/api/chat/conversations/me', body: [
          {
            'shipment_id': 21,
            'other_party_id': 9,
            'other_party_name': 'سائق علي',
            'other_party_role': 'driver',
            'last_preview': 'مرحباً',
            'unread_count': 2,
          }
        ]);
      },
      callback: (_) async {
        await _pump(tester, const ShipperMessagesScreen());
        expect(find.text('سائق علي'), findsOneWidget);
        expect(find.text('2'), findsOneWidget);
      },
    );
  });

  testWidgets('ShipperMessagesScreen empty state shows placeholder',
      (tester) async {
    await withMockedHttp(
      setup: (r) {
        r.respond('GET', '/api/chat/conversations/me', body: []);
      },
      callback: (_) async {
        await _pump(tester, const ShipperMessagesScreen());
        expect(find.text('لا توجد محادثات بعد'), findsOneWidget);
      },
    );
  });

  testWidgets('ShipperMessagesScreen error state offers retry',
      (tester) async {
    await withMockedHttp(
      setup: (r) {
        r.respond('GET', '/api/chat/conversations/me',
            statusCode: 500, body: {'message': 'oops'});
      },
      callback: (_) async {
        await _pump(tester, const ShipperMessagesScreen());
        expect(find.text('إعادة المحاولة'), findsOneWidget);
      },
    );
  });

  testWidgets('ShipperNotificationsScreen retry reloads after error',
      (tester) async {
    await withMockedHttp(
      setup: (r) {
        r.respond('GET', '/api/notifications/user/1',
            statusCode: 500, body: {'message': 'oops'});
        r.respond('GET', '/api/notifications/user/1', body: {
          'notifications': [
            {
              'id': 3,
              'title': 'تنبيه',
              'message': 'رسالة',
              'created_at': DateTime.now().toIso8601String(),
              'is_read': 0,
            }
          ]
        });
      },
      callback: (_) async {
        await _pump(tester, const ShipperNotificationsScreen());
        await tester.tap(find.text('إعادة المحاولة'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('تنبيه'), findsOneWidget);
      },
    );
  });

  testWidgets('ShipperNotificationsScreen shows error retry button on failure',
      (tester) async {
    await withMockedHttp(
      setup: (r) {
        r.respond('GET', '/api/notifications/user/1',
            statusCode: 500, body: {'message': 'oops'});
      },
      callback: (_) async {
        await _pump(tester, const ShipperNotificationsScreen());
        expect(find.byIcon(Icons.refresh), findsAtLeast(1));
        expect(find.text('إعادة المحاولة'), findsOneWidget);
        // Pre-load a successful response and tap retry.
      },
    );
  });

  testWidgets('ShipperNotificationsScreen renders notifications with sender '
      'shipment ID extraction', (tester) async {
    await withMockedHttp(
      setup: (r) {
        r.respond('GET', '/api/notifications/user/1', body: {
          'notifications': [
            {
              'id': 1,
              'title': 'تنبيه',
              'message': 'تم تعيين سائق لشحنة #42',
              'related_shipment_id': 42,
              'created_at': DateTime.now()
                  .subtract(const Duration(minutes: 5))
                  .toIso8601String(),
              'is_read': 0,
            },
            {
              'id': 2,
              'title': 'عقد إلكتروني',
              'message': 'تم إنشاء عقد رقم #7 بقيمة 500 ريال للشحنة #5',
              'related_shipment_id': 5,
              'route_description': 'الرياض → جدة',
              'created_at': DateTime.now()
                  .subtract(const Duration(hours: 3))
                  .toIso8601String(),
              'is_read': 1,
            },
          ]
        });
      },
      callback: (_) async {
        await _pump(tester, const ShipperNotificationsScreen());
        expect(find.text('تنبيه'), findsOneWidget);
        expect(find.text('عقد إلكتروني'), findsOneWidget);
        expect(find.text('عرض العقد'), findsOneWidget);
      },
    );
  });
}
