import 'package:darbak/driver_home.dart';
import 'package:darbak/ratings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
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
      home: Directionality(textDirection: TextDirection.rtl, child: child),
    );

Future<void> _pump(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(1200, 3600);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(_wrap(Scaffold(body: child)));
  for (var i = 0; i < 14; i++) {
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

  testWidgets('ShipmentSummaryScreen shows late penalty banner', (tester) async {
    final shipment = {
      'id': 7,
      'shipper_id': 2,
      'driver_id': 1,
      'status': 'en_route',
      'pickup_address': 'الرياض',
      'dropoff_address': 'جدة',
      'weight_kg': 1200,
      'accepted_bid_amount': 1500,
      'final_price': 1500,
      'expected_delivery_date':
          DateTime.now().subtract(const Duration(days: 12)).toIso8601String(),
      'contract_pdf_key': 'contracts/7.pdf',
      'created_at': '2026-01-01T00:00:00Z',
    };
    await withMockedHttp(
      setup: (r) {
        r.respond('GET', '/api/shipments/7', body: shipment);
        r.respond('GET', '/api/shipments/7/contract',
            body: {'url': 'https://cdn.test/c.pdf'});
      },
      callback: (_) async {
        await _pump(
          tester,
          ShipmentSummaryScreen(shipment: shipment),
        );
        expect(find.textContaining('جزاء تأخير'), findsOneWidget);
        expect(find.text('العقد الإلكتروني'), findsOneWidget);
      },
    );
  });

  testWidgets('ShipmentSummaryScreen delivered exposes rate button',
      (tester) async {
    final shipment = {
      'id': 8,
      'shipper_id': 2,
      'driver_id': 1,
      'status': 'delivered',
      'pickup_address': 'الرياض',
      'dropoff_address': 'جدة',
      'weight_kg': 800,
      'accepted_bid_amount': 1200,
      'final_price': 1200,
      'created_at': '2026-01-01T00:00:00Z',
    };
    await withMockedHttp(
      setup: (r) {
        r.respond('GET', '/api/shipments/8', body: shipment);
        r.respond('GET', '/api/users/2/profile', body: {
          'data': {'id': 2, 'name': 'شاحن', 'role': 'shipper'}
        });
      },
      callback: (_) async {
        await _pump(
          tester,
          ShipmentSummaryScreen(shipment: shipment),
        );
        final rateBtn = find.text('تقييم الطرف الآخر');
        expect(rateBtn, findsOneWidget);
        await tester.tap(rateBtn);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        expect(find.byType(RatingsScreen), findsOneWidget);
      },
    );
  });

}
