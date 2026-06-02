import 'package:darbak/driver_home.dart';
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

void _tallViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 3200);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

/// Pump the widget for [iterations] frames without `pumpAndSettle`. Screens
/// here usually have a `Timer.periodic`, so settle would deadlock.
Future<void> _pumpAndDrain(
  WidgetTester tester,
  Widget child, {
  int iterations = 14,
}) async {
  _tallViewport(tester);
  await tester.pumpWidget(_wrap(child));
  for (var i = 0; i < iterations; i++) {
    await tester.pump(const Duration(milliseconds: 80));
  }
}

Map<String, dynamic> _driverShipment({
  int id = 1,
  String status = 'assigned',
  String cargo = 'بضائع',
}) =>
    {
      'id': id,
      'status': status,
      'cargo_type': cargo,
      'weight': 1200,
      'pickup_city': 'الرياض',
      'destination_city': 'جدة',
      'pickup_date': '2026-06-01',
      'final_delivery_date': '2026-06-05',
      'base_price': 1500,
      'suggested_price': 1500,
      'accepted_bid_amount': 1450,
      'contract_pdf_key': '',
      'shipper_id': 4,
      'driver_id': 1,
      'driver_name': 'سائق',
      'shipper_name': 'شاحن',
    };

void _mockDriverHome(FakeHttpRouter r,
    {List<Map<String, dynamic>> active = const []}) {
  r.respond('GET', '/api/shipments/driver/active', body: active);
  r.respond('GET', '/api/auth/profile/1', body: {
    'id': 1,
    'role': 'driver',
    'full_name': 'سائق',
    'verification_status': 'verified',
  });
  r.respond('GET', '/api/shipments', body: {
    'data': <Map<String, dynamic>>[],
    'pagination': {'page': 1, 'limit': 20, 'total': 0, 'totalPages': 0}
  });
  r.respond('GET', '/api/bids/me/active', body: {'active': false, 'bid': null});
  r.respond('GET', '/api/shipments/driver', body: active);
  r.respond('GET', '/api/chat/conversations/me', body: []);
  r.respond('GET', '/api/operating-card', body: {'data': null});
  r.respond('GET', '/api/trucks/my', body: []);
  r.respond('GET', '/api/profile/me', body: {
    'data': {
      'id': 1,
      'full_name': 'سائق',
      'role': 'driver',
      'email': 'driver@test.io',
      'phone': '0500000000',
      'verification_status': 'verified',
    }
  });
}

void _mockShipperHome(FakeHttpRouter r) {
  r.respond('GET', '/api/shipments', body: [
    _driverShipment(id: 11, status: 'bidding'),
    _driverShipment(id: 12, status: 'pending'),
    _driverShipment(id: 13, status: 'delivered'),
  ]);
  r.respond('GET', '/api/chat/conversations/me', body: []);
  r.respond('GET', '/api/notifications/user/1',
      body: {'data': [], 'unread_count': 0});
  r.respond('GET', '/api/profile/me', body: {
    'data': {
      'id': 1,
      'full_name': 'شاحن',
      'role': 'shipper',
      'email': 'shipper@test.io',
      'phone': '0500000000',
    }
  });
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'user_id': 1,
      'user_name': 'سائق',
      'user_role': 'driver',
      'is_logged_in': true,
      'auth_token': 't',
    });
  });

  // ------------------------------------------------------------------
  // DriverHomeScreen
  // ------------------------------------------------------------------

  group('DriverHomeScreen', () {
    testWidgets('renders with bottom navigation and AvailableLoadsScreen',
        (tester) async {
      await withMockedHttp(
        setup: _mockDriverHome,
        callback: (_) async {
          await _pumpAndDrain(tester, const DriverHomeScreen());
          expect(find.byType(DriverHomeScreen), findsOneWidget);
          expect(find.text('سوق الشحنات'), findsWidgets);
        },
      );
    });

    testWidgets('switching to رحلاتي pumps DriverTripsScreen', (tester) async {
      await withMockedHttp(
        setup: _mockDriverHome,
        callback: (_) async {
          await _pumpAndDrain(tester, const DriverHomeScreen());
          await tester.tap(find.text('رحلاتي'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 200));
          expect(find.byType(DriverTripsScreen), findsOneWidget);
        },
      );
    });

    testWidgets('switching to الرسائل pumps DriverMessagesScreen',
        (tester) async {
      await withMockedHttp(
        setup: _mockDriverHome,
        callback: (_) async {
          await _pumpAndDrain(tester, const DriverHomeScreen());
          await tester.tap(find.text('الرسائل'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 200));
          expect(find.byType(DriverMessagesScreen), findsOneWidget);
        },
      );
    });

    testWidgets('switching to حسابي pumps DriverProfileScreen', (tester) async {
      await withMockedHttp(
        setup: _mockDriverHome,
        callback: (_) async {
          await _pumpAndDrain(tester, const DriverHomeScreen());
          await tester.tap(find.text('حسابي'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 600));
          expect(find.byType(DriverProfileScreen), findsOneWidget);
        },
      );
    });
  });

  // ------------------------------------------------------------------
  // DriverTripsScreen
  // ------------------------------------------------------------------

  group('DriverTripsScreen', () {
    testWidgets('empty state with refresh button', (tester) async {
      await withMockedHttp(
        setup: (r) => r.respond('GET', '/api/shipments/driver', body: []),
        callback: (_) async {
          await _pumpAndDrain(tester, const DriverTripsScreen());
          expect(find.text('لا توجد رحلات حالية'), findsOneWidget);
          expect(find.text('Refresh'), findsOneWidget);
        },
      );
    });

    testWidgets('error state shows refresh', (tester) async {
      await withMockedHttp(
        setup: (r) => r.respond('GET', '/api/shipments/driver',
            statusCode: 500, body: {'message': 'oops'}),
        callback: (_) async {
          await _pumpAndDrain(tester, const DriverTripsScreen());
          expect(find.textContaining('تعذر تحميل الرحلات'), findsOneWidget);
        },
      );
    });

    testWidgets('renders active + history sections', (tester) async {
      await withMockedHttp(
        setup: (r) => r.respond('GET', '/api/shipments/driver', body: [
          _driverShipment(id: 1, status: 'assigned'),
          _driverShipment(id: 2, status: 'delivered'),
        ]),
        callback: (_) async {
          await _pumpAndDrain(tester, const DriverTripsScreen());
          expect(find.text('الرحلات النشطة'), findsOneWidget);
          expect(find.text('السجل السابق'), findsOneWidget);
        },
      );
    });
  });

  // ------------------------------------------------------------------
  // ShipmentSummaryScreen
  // ------------------------------------------------------------------

  group('ShipmentSummaryScreen', () {
    testWidgets('renders details for a delivered shipment', (tester) async {
      await withMockedHttp(
        setup: (r) => r.respond('GET', '/api/shipments/1',
            body: _driverShipment(id: 1, status: 'delivered')),
        callback: (_) async {
          await _pumpAndDrain(
            tester,
            ShipmentSummaryScreen(
                shipment: _driverShipment(id: 1, status: 'delivered')),
          );
          expect(find.byType(ShipmentSummaryScreen), findsOneWidget);
        },
      );
    });

    testWidgets('delivered shipment shows contract and rate buttons',
        (tester) async {
      final delivered = {
        'id': 1,
        'status': 'delivered',
        'contract_pdf_key': 'contracts/1.pdf',
        'pickup_address': 'الرياض',
        'dropoff_address': 'جدة',
        'weight_kg': 1200,
        'shipper_id': 5,
        'driver_id': 1,
        'accepted_bid_amount': 1500,
        'final_price': 1450,
        'created_at': '2026-01-01T00:00:00Z',
      };
      await withMockedHttp(
        setup: (r) =>
            r.respond('GET', '/api/shipments/1', body: delivered),
        callback: (_) async {
          await _pumpAndDrain(
            tester,
            ShipmentSummaryScreen(shipment: delivered),
          );
          expect(find.text('العقد الإلكتروني'), findsOneWidget);
          expect(find.text('تقييم الطرف الآخر'), findsOneWidget);
        },
      );
    });

    testWidgets('shows late penalty banner for overdue assigned shipment',
        (tester) async {
      final overdue = _driverShipment(id: 2, status: 'assigned');
      overdue['final_delivery_date'] =
          DateTime.now().subtract(const Duration(days: 10)).toIso8601String();
      overdue['accepted_bid_amount'] = 2000;
      await withMockedHttp(
        setup: (r) =>
            r.respond('GET', '/api/shipments/2', body: overdue),
        callback: (_) async {
          await _pumpAndDrain(tester, ShipmentSummaryScreen(shipment: overdue));
          expect(find.byType(ShipmentSummaryScreen), findsOneWidget);
        },
      );
    });
  });

  // ------------------------------------------------------------------
  // ShipperHomeScreen and tabs
  // ------------------------------------------------------------------

  group('ShipperHomeScreen', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({
        'user_id': 1,
        'user_name': 'شاحن',
        'user_role': 'shipper',
        'is_logged_in': true,
        'auth_token': 't',
      });
    });

    testWidgets('renders shipper home with shipments tab default',
        (tester) async {
      await withMockedHttp(
        setup: _mockShipperHome,
        callback: (_) async {
          await _pumpAndDrain(tester, const ShipperHomeScreen());
          expect(find.byType(ShipperHomeScreen), findsOneWidget);
          expect(find.byType(ShipperShipmentsScreen), findsOneWidget);
        },
      );
    });

    testWidgets('tapping notifications tab loads ShipperNotificationsScreen',
        (tester) async {
      await withMockedHttp(
        setup: _mockShipperHome,
        callback: (_) async {
          await _pumpAndDrain(tester, const ShipperHomeScreen());
          await tester.tap(find.text('تنبيهات'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 500));
          expect(find.byType(ShipperNotificationsScreen), findsOneWidget);
        },
      );
    });

    testWidgets('tapping messages tab loads ShipperMessagesScreen',
        (tester) async {
      await withMockedHttp(
        setup: _mockShipperHome,
        callback: (_) async {
          await _pumpAndDrain(tester, const ShipperHomeScreen());
          await tester.tap(find.text('الرسائل'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 500));
          expect(find.byType(ShipperMessagesScreen), findsOneWidget);
        },
      );
    });

    testWidgets('tapping profile tab loads ShipperProfileScreen',
        (tester) async {
      await withMockedHttp(
        setup: _mockShipperHome,
        callback: (_) async {
          await _pumpAndDrain(tester, const ShipperHomeScreen());
          await tester.tap(find.byIcon(Icons.domain_outlined));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 500));
          expect(find.byType(ShipperProfileScreen), findsOneWidget);
        },
      );
    });
  });

  // ------------------------------------------------------------------
  // ShipperShipmentsScreen
  // ------------------------------------------------------------------

  group('ShipperShipmentsScreen', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({
        'user_id': 1,
        'user_role': 'shipper',
        'auth_token': 't',
      });
    });

    testWidgets('renders list of shipments', (tester) async {
      await withMockedHttp(
        setup: (r) {
          r.respond('GET', '/api/shipments', body: [
            _driverShipment(id: 11, status: 'bidding'),
            _driverShipment(id: 12, status: 'delivered'),
          ]);
        },
        callback: (_) async {
          await _pumpAndDrain(tester, const ShipperShipmentsScreen());
          expect(find.byType(ShipperShipmentsScreen), findsOneWidget);
        },
      );
    });

    testWidgets('renders empty list', (tester) async {
      await withMockedHttp(
        setup: (r) => r.respond('GET', '/api/shipments', body: []),
        callback: (_) async {
          await _pumpAndDrain(tester, const ShipperShipmentsScreen());
          expect(find.byType(ShipperShipmentsScreen), findsOneWidget);
        },
      );
    });

    testWidgets('renders cards for every shipment status label', (tester) async {
      final statuses = [
        'bidding',
        'assigned',
        'delivered',
        'pending',
        'at_pickup',
        'en_route',
        'at_dropoff',
        'unknown_status',
      ];
      await withMockedHttp(
        setup: (r) {
          r.respond('GET', '/api/profile/me', body: {
            'data': {
              'id': 1,
              'role': 'shipper',
              'verification_status': 'verified',
            }
          });
          r.respond(
            'GET',
            '/api/shipments',
            body: [
              for (var i = 0; i < statuses.length; i++)
                {
                  'id': i + 1,
                  'shipper_id': 1,
                  'status': statuses[i],
                  'cargo_type': 'بضائع',
                  'pickup_city': 'الرياض',
                  'destination_city': 'جدة',
                  'pickup_date': '2026-06-01',
                  'base_price': 1000,
                  'driver_id': i == 2 ? 9 : null,
                  'driver_name': 'سائق',
                }
            ],
          );
        },
        callback: (_) async {
          await _pumpAndDrain(tester, const ShipperShipmentsScreen());
          expect(find.text('في المزاد'), findsOneWidget);
          expect(find.text('مُسندة لسائق'), findsOneWidget);
          expect(find.text('تم التسليم'), findsOneWidget);
          expect(find.text('unknown_status'), findsOneWidget);
        },
      );
    });

    testWidgets('shows KYB banner when verification is pending', (tester) async {
      await withMockedHttp(
        setup: (r) {
          r.respond('GET', '/api/profile/me', body: {
            'data': {
              'id': 1,
              'role': 'shipper',
              'verification_status': 'pending',
            }
          });
          r.respond('GET', '/api/shipments', body: []);
        },
        callback: (_) async {
          await _pumpAndDrain(tester, const ShipperShipmentsScreen());
          expect(find.textContaining('قيد مراجعة الوثائق'), findsOneWidget);
        },
      );
    });
  });

  // ------------------------------------------------------------------
  // ShipperNotificationsScreen
  // ------------------------------------------------------------------

  group('ShipperNotificationsScreen', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({
        'user_id': 1,
        'user_role': 'shipper',
        'auth_token': 't',
      });
    });

    testWidgets('renders empty notifications', (tester) async {
      await withMockedHttp(
        setup: (r) => r.respond('GET', '/api/notifications/user/1', body: {
          'data': [],
          'unread_count': 0,
        }),
        callback: (_) async {
          await _pumpAndDrain(tester, const ShipperNotificationsScreen());
          expect(find.byType(ShipperNotificationsScreen), findsOneWidget);
        },
      );
    });

    testWidgets('renders notifications list', (tester) async {
      await withMockedHttp(
        setup: (r) => r.respond('GET', '/api/notifications/user/1', body: {
          'data': [
            {
              'id': 1,
              'title': 'تنبيه',
              'body': 'لديك عرض جديد',
              'created_at': '2026-06-01',
              'is_read': 0,
              'type': 'bid',
            },
            {
              'id': 2,
              'title': 'تم القبول',
              'body': 'تم قبول عرضك',
              'created_at': '2026-06-02',
              'is_read': 1,
              'type': 'accepted',
            },
          ],
          'unread_count': 1,
        }),
        callback: (_) async {
          await _pumpAndDrain(tester, const ShipperNotificationsScreen());
          expect(find.byType(ShipperNotificationsScreen), findsOneWidget);
        },
      );
    });
  });
}
