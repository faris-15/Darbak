import 'package:darbak/driver_home.dart';
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
      'user_role': 'driver',
      'auth_token': 't',
    });
  });

  testWidgets('DriverMessagesScreen renders conversation rows', (tester) async {
    await withMockedHttp(
      setup: (r) {
        r.respond('GET', '/api/chat/conversations/me', body: [
          {
            'shipment_id': 11,
            'other_party_id': 2,
            'other_party_name': 'الشاحن',
            'other_party_role': 'shipper',
            'last_preview': 'مرحبا',
            'unread_count': 3,
          },
          {
            'shipment_id': 12,
            'other_party_id': 4,
            'other_party_name': 'شركة الاختبار',
            'other_party_role': 'shipper',
            'last_preview': 'تم التسليم',
            'unread_count': 0,
          },
        ]);
      },
      callback: (_) async {
        await _pump(tester, const DriverMessagesScreen());
        expect(find.text('الشاحن'), findsOneWidget);
        expect(find.text('شركة الاختبار'), findsOneWidget);
        expect(find.text('3'), findsOneWidget);
      },
    );
  });

  testWidgets('DriverMessagesScreen empty state', (tester) async {
    await withMockedHttp(
      setup: (r) {
        r.respond('GET', '/api/chat/conversations/me', body: []);
      },
      callback: (_) async {
        await _pump(tester, const DriverMessagesScreen());
        expect(find.text('لا توجد محادثات بعد'), findsOneWidget);
      },
    );
  });

  testWidgets('DriverMessagesScreen error state offers retry', (tester) async {
    await withMockedHttp(
      setup: (r) {
        r.respond('GET', '/api/chat/conversations/me',
            statusCode: 500, body: {'message': 'oops'});
      },
      callback: (_) async {
        await _pump(tester, const DriverMessagesScreen());
        expect(find.text('إعادة المحاولة'), findsOneWidget);
      },
    );
  });

  testWidgets('ShipmentSummaryScreen delivered shows rate button',
      (tester) async {
    final shipment = {
      'id': 6,
      'status': 'delivered',
      'pickup_address': 'الرياض',
      'dropoff_address': 'جدة',
      'shipper_id': 2,
      'driver_id': 1,
      'accepted_bid_amount': 2000,
      'expected_delivery_date': '2026-06-01',
      'contract_pdf_key': 'contracts/6.pdf',
    };
    await withMockedHttp(
      setup: (r) {
        r.respond('GET', '/api/shipments/6', body: shipment);
      },
      callback: (_) async {
        await _pump(tester, ShipmentSummaryScreen(shipment: shipment));
        expect(find.text('تقييم الطرف الآخر'), findsOneWidget);
        expect(find.text('العقد الإلكتروني'), findsOneWidget);
      },
    );
  });

  testWidgets('ShipmentSummaryScreen with late penalty shows banner',
      (tester) async {
    final shipment = {
      'id': 5,
      'status': 'en_route',
      'pickup_address': 'الرياض',
      'dropoff_address': 'جدة',
      'weight_kg': 1200,
      'shipper_id': 2,
      'driver_id': 1,
      'accepted_bid_amount': 2000,
      'final_price': null,
      'expected_delivery_date':
          DateTime.now().subtract(const Duration(days: 8)).toIso8601String(),
      'created_at': '2026-01-01T00:00:00Z',
    };
    await withMockedHttp(
      setup: (r) {
        r.respond('GET', '/api/shipments/5', body: shipment);
      },
      callback: (_) async {
        await _pump(tester, ShipmentSummaryScreen(shipment: shipment));
        expect(find.byType(ShipmentSummaryScreen), findsOneWidget);
        expect(find.textContaining('تأخير: تم تطبيق خصم'), findsOneWidget);
      },
    );
  });
}
