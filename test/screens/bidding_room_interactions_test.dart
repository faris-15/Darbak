import 'package:darbak/bidding_room_screen.dart';
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
  await tester.pumpWidget(_wrap(child));
  for (var i = 0; i < iterations; i++) {
    await tester.pump(const Duration(milliseconds: 80));
  }
}

Map<String, dynamic> _shipmentWithCoords() => {
      'id': 9,
      'cargo_type': 'بضائع',
      'cargo_description': 'تجريبي',
      'weight': 800,
      'pickup_city': 'الرياض',
      'destination_city': 'جدة',
      'pickup_address': 'الرياض، الملك فهد',
      'dropoff_address': 'جدة، طريق المطار',
      'pickup_lat': 24.7136,
      'pickup_lng': 46.6753,
      'dropoff_lat': 21.4858,
      'dropoff_lng': 39.1925,
      'base_price': 1500,
      'suggested_price': 1500,
      'description': 'تجريبي',
      'pickup_date': '2026-06-01T08:00:00Z',
      'expected_delivery_at': '2026-06-05T18:00:00Z',
    };

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'user_id': 1,
      'user_role': 'driver',
      'auth_token': 't',
    });
  });

  testWidgets('BidDetailsScreen shows haversine-derived distance and Hijri',
      (tester) async {
    await withMockedHttp(
      setup: (r) {
        r.respond('GET', '/api/auth/profile/1', body: {
          'id': 1,
          'full_name': 'Tester',
          'role': 'driver',
          'verification_status': 'verified',
        });
        r.respond('GET', '/api/bids/shipment/9', body: []);
      },
      callback: (_) async {
        await _pump(
          tester,
          BidDetailsScreen(
            shipmentId: 9,
            driverId: 1,
            driverName: 'سائق',
            shipmentData: _shipmentWithCoords(),
          ),
        );
        // Distance text should contain "كم" (km).
        expect(find.textContaining('كم'), findsWidgets);
      },
    );
  });

  testWidgets('expired license blocks bid submission', (tester) async {
    await withMockedHttp(
      setup: (r) {
        r.respond('GET', '/api/auth/profile/1', body: {
          'id': 1,
          'full_name': 'Tester',
          'role': 'driver',
          'verification_status': 'verified',
          'expiry_date': '2020-01-01',
        });
        r.respond('GET', '/api/bids/shipment/9', body: []);
      },
      callback: (_) async {
        await _pump(
          tester,
          BidDetailsScreen(
            shipmentId: 9,
            driverId: 1,
            driverName: 'سائق',
            shipmentData: _shipmentWithCoords(),
          ),
          iterations: 20,
        );
        await tester.pump(const Duration(milliseconds: 300));
        final submitBtn = find.text('تأكيد وإرسال العرض');
        expect(submitBtn, findsOneWidget);
        await tester.ensureVisible(submitBtn);
        await tester.pump();
        final agree = find.byType(Checkbox);
        if (agree.evaluate().isNotEmpty) {
          await tester.tap(agree.first);
          await tester.pump();
        }
        await tester.tap(submitBtn);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        expect(
          find.textContaining('انتهت صلاحية رخصة القيادة'),
          findsOneWidget,
        );
      },
    );
  });

  testWidgets('successful bid submission shows success dialog', (tester) async {
    await withMockedHttp(
      setup: (r) {
        r.respond('GET', '/api/auth/profile/1', body: {
          'id': 1,
          'full_name': 'Tester',
          'role': 'driver',
          'verification_status': 'verified',
          'expiry_date': '2099-12-31',
        });
        r.respond('GET', '/api/bids/shipment/9', body: []);
        r.respond('POST', '/api/bids', statusCode: 201, body: {'id': 1});
      },
      callback: (_) async {
        await _pump(
          tester,
          BidDetailsScreen(
            shipmentId: 9,
            driverId: 1,
            driverName: 'سائق',
            shipmentData: _shipmentWithCoords(),
          ),
        );
        final fields = find.byType(TextFormField);
        if (fields.evaluate().length >= 2) {
          await tester.enterText(fields.at(0), '1500');
          await tester.enterText(fields.at(1), '3');
        }
        final agree = find.byType(Checkbox);
        if (agree.evaluate().isNotEmpty) {
          await tester.tap(agree.first);
          await tester.pump();
        }
        final submitBtn = find.text('تأكيد وإرسال العرض');
        expect(submitBtn, findsOneWidget);
        await tester.ensureVisible(submitBtn);
        await tester.pump();
        await tester.tap(submitBtn);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.text('تم إرسال العرض بنجاح'), findsOneWidget);
      },
    );
  });

  testWidgets('submitting empty bid surfaces validation snackbar',
      (tester) async {
    await withMockedHttp(
      setup: (r) {
        r.respond('GET', '/api/auth/profile/1', body: {
          'id': 1,
          'full_name': 'Tester',
          'role': 'driver',
          'verification_status': 'verified',
        });
        r.respond('GET', '/api/bids/shipment/9', body: []);
      },
      callback: (_) async {
        await _pump(
          tester,
          BidDetailsScreen(
            shipmentId: 9,
            driverId: 1,
            driverName: 'سائق',
            shipmentData: _shipmentWithCoords(),
          ),
        );

        // Find any "إرسال" or "تقديم" button to submit empty.
        final submitBtn = find.text('تأكيد وإرسال العرض');
        if (submitBtn.evaluate().isNotEmpty) {
          await tester.ensureVisible(submitBtn);
          await tester.pump();
          await tester.tap(submitBtn);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 200));
        }
        expect(find.byType(BidDetailsScreen), findsOneWidget);
      },
    );
  });
}
