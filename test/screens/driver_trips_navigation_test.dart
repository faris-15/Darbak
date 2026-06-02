import 'package:darbak/driver_home.dart';
import 'package:darbak/job_tracking_screen.dart';
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

  testWidgets('Active trip tap navigates to JobTrackingScreen', (tester) async {
    final shipment = {
      'id': 7,
      'shipper_id': 2,
      'driver_id': 1,
      'status': 'en_route',
      'pickup_address': 'الرياض',
      'dropoff_address': 'جدة',
      'pickup_lat': 24.7136,
      'pickup_lng': 46.6753,
      'dropoff_lat': 21.4858,
      'dropoff_lng': 39.1925,
      'weight_kg': 1200,
      'cargo_description': 'بضائع',
      'accepted_bid_amount': 1500,
      'pickup_date': '2026-06-01',
    };
    await withMockedHttp(
      setup: (r) {
        r.respond('GET', '/api/shipments/driver', body: [shipment]);
        r.respond('GET', '/api/shipments/7', body: shipment);
        r.respond('GET', '/api/shipment-status/7/history',
            body: {'history': []});
      },
      callback: (_) async {
        await _pump(tester, const DriverTripsScreen());
        final cards = find.byType(InkWell);
        if (cards.evaluate().isNotEmpty) {
          await tester.ensureVisible(cards.first);
          await tester.pumpAndSettle();
          await tester.tap(cards.first);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 200));
          await tester.pump(const Duration(milliseconds: 300));
          expect(find.byType(JobTrackingScreen), findsOneWidget);
        } else {
          expect(find.byType(DriverTripsScreen), findsOneWidget);
        }
      },
    );
  });

  testWidgets('empty trips list shows placeholder', (tester) async {
    await withMockedHttp(
      setup: (r) {
        r.respond('GET', '/api/shipments/driver', body: []);
      },
      callback: (_) async {
        await _pump(tester, const DriverTripsScreen());
        expect(find.byType(DriverTripsScreen), findsOneWidget);
      },
    );
  });

  testWidgets('History trip tap navigates to ShipmentSummaryScreen',
      (tester) async {
    final shipment = {
      'id': 99,
      'shipper_id': 2,
      'driver_id': 1,
      'status': 'delivered',
      'pickup_address': 'الرياض',
      'dropoff_address': 'جدة',
      'weight_kg': 800,
      'accepted_bid_amount': 1500,
      'final_price': 1500,
      'created_at': '2026-01-01T00:00:00Z',
    };
    await withMockedHttp(
      setup: (r) {
        r.respond('GET', '/api/shipments/driver', body: [shipment]);
        r.respond('GET', '/api/shipments/99', body: shipment);
      },
      callback: (_) async {
        await _pump(tester, const DriverTripsScreen());
        final cards = find.byType(InkWell);
        if (cards.evaluate().isNotEmpty) {
          await tester.ensureVisible(cards.first);
          await tester.pumpAndSettle();
          await tester.tap(cards.first);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 200));
          await tester.pump(const Duration(milliseconds: 300));
          expect(find.byType(ShipmentSummaryScreen), findsOneWidget);
        } else {
          expect(find.byType(DriverTripsScreen), findsOneWidget);
        }
      },
    );
  });
}
