import 'package:darbak/ratings_screen.dart';
import 'package:darbak/shipper_home.dart';
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
  await tester.pumpWidget(_wrap(child));
  for (var i = 0; i < 14; i++) {
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

  testWidgets('ShipperShipmentsScreen rejected KYB shows rejection banner',
      (tester) async {
    await withMockedHttp(
      setup: (r) {
        r.respond('GET', '/api/profile/me', body: {
          'data': {'id': 1, 'role': 'shipper', 'verification_status': 'rejected'}
        });
        r.respond('GET', '/api/shipments', body: []);
      },
      callback: (_) async {
        await _pump(tester, const ShipperShipmentsScreen());
        expect(find.textContaining('لم تُقبل وثائق الشركة'), findsOneWidget);
      },
    );
  });

  testWidgets('delivered shipment exposes rate-driver button', (tester) async {
    await withMockedHttp(
      setup: (r) {
        r.respond('GET', '/api/profile/me', body: {
          'data': {'id': 1, 'role': 'shipper', 'verification_status': 'verified'}
        });
        r.respond('GET', '/api/shipments', body: [
          {
            'id': 30,
            'shipper_id': 1,
            'driver_id': 9,
            'driver_name': 'سائق',
            'status': 'delivered',
            'pickup_city': 'الرياض',
            'destination_city': 'جدة',
            'pickup_address': 'الرياض',
            'dropoff_address': 'جدة',
            'cargo_type': 'بضائع',
            'base_price': 1000,
            'pickup_date': '2026-06-01',
          }
        ]);
        r.respond('GET', '/api/users/9/profile', body: {
          'data': {'id': 9, 'name': 'سائق', 'role': 'driver'}
        });
      },
      callback: (_) async {
        await _pump(tester, const ShipperShipmentsScreen());
        final rate = find.textContaining('تقييم السائق');
        expect(rate, findsOneWidget);
        await tester.tap(rate.first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        expect(find.byType(RatingsScreen), findsOneWidget);
      },
    );
  });

  testWidgets('CreateShipmentScreen renders truck configuration form',
      (tester) async {
    await _pump(tester, const CreateShipmentScreen());
    expect(find.byType(CreateShipmentScreen), findsOneWidget);
    expect(find.textContaining('شحنة'), findsWidgets);
  });

  testWidgets('ShipperContractScreen renders static contract copy',
      (tester) async {
    await _pump(tester, const ShipperContractScreen());
    expect(find.text('العقد الإلكتروني'), findsOneWidget);
    expect(find.textContaining('بند خصم التأخير'), findsOneWidget);
  });
}
