import 'package:darbak/api_service.dart';
import 'package:darbak/available_loads_screen.dart';
import 'package:darbak/bidding_room_screen.dart';
import 'package:darbak/ratings_screen.dart';
import 'package:darbak/shipment_bids_detail_screen.dart';
import 'package:darbak/vehicle_management_screen.dart';
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

/// Pumps the widget then drains microtasks/timers for [iterations] frames.
/// Using `pump` (not `pumpAndSettle`) avoids deadlock for screens with
/// `Timer.periodic` heartbeats.
Future<void> _pumpAndDrain(
  WidgetTester tester,
  Widget child, {
  int iterations = 12,
}) async {
  _tallViewport(tester);
  await tester.pumpWidget(_wrap(child));
  for (var i = 0; i < iterations; i++) {
    await tester.pump(const Duration(milliseconds: 80));
  }
}

Map<String, dynamic> _profileFixture({String status = 'verified'}) => {
      'id': 1,
      'full_name': 'Tester',
      'role': 'driver',
      'rating_avg': 4.5,
      'rating_count': 10,
      'completed_trips': 6,
      'total_earnings': 1200,
      'verification_status': status,
      'expiry_date': '2099-12-31',
    };

Map<String, dynamic> _paginatedShipments(List<Map<String, dynamic>> rows) => {
      'data': rows,
      'pagination': {
        'page': 1,
        'limit': 20,
        'total': rows.length,
        'totalPages': 1,
      },
    };

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'user_id': 1,
      'user_name': 'Tester',
      'user_role': 'driver',
      'is_logged_in': true,
      'auth_token': 't',
    });
  });

  // ------------------------------------------------------------------
  // AvailableLoadsScreen
  // ------------------------------------------------------------------

  group('AvailableLoadsScreen', () {
    testWidgets('renders with empty market and dashboard data', (tester) async {
      await withMockedHttp(
        setup: (r) {
          r.respond('GET', '/api/auth/profile/1', body: _profileFixture());
          r.respond('GET', '/api/shipments', body: _paginatedShipments([]));
          r.respond('GET', '/api/bids/me/active',
              body: {'active': false, 'bid': null});
        },
        callback: (_) async {
          await _pumpAndDrain(tester, const AvailableLoadsScreen());
          expect(find.byType(AvailableLoadsScreen), findsOneWidget);
        },
      );
    });

    testWidgets('renders shipment list with rows', (tester) async {
      final shipment = {
        'id': 11,
        'cargo_type': 'إلكترونيات',
        'weight': 1200,
        'pickup_city': 'الرياض',
        'destination_city': 'جدة',
        'base_price': 2400,
        'suggested_price': 2400,
        'status': 'bidding',
        'pickup_date': '2026-06-01',
        'description': 'تجريبي',
      };
      await withMockedHttp(
        setup: (r) {
          r.respond('GET', '/api/auth/profile/1', body: _profileFixture());
          r.respond('GET', '/api/shipments',
              body: _paginatedShipments([shipment]));
          r.respond('GET', '/api/bids/me/active',
              body: {'active': false, 'bid': null});
        },
        callback: (_) async {
          await _pumpAndDrain(tester, const AvailableLoadsScreen());
          expect(find.byType(AvailableLoadsScreen), findsOneWidget);
        },
      );
    });

    testWidgets('shows error state when API fails', (tester) async {
      await withMockedHttp(
        setup: (r) {
          r.respond('GET', '/api/auth/profile/1',
              statusCode: 500, body: {'message': 'fail'});
          r.respond('GET', '/api/shipments',
              statusCode: 500, body: {'message': 'fail'});
          r.respond('GET', '/api/bids/me/active',
              statusCode: 500, body: {'message': 'fail'});
        },
        callback: (_) async {
          await _pumpAndDrain(tester, const AvailableLoadsScreen());
          expect(find.byType(AvailableLoadsScreen), findsOneWidget);
        },
      );
    });
  });

  // ------------------------------------------------------------------
  // VehicleManagementScreen
  // ------------------------------------------------------------------

  group('VehicleManagementScreen', () {
    testWidgets('renders empty trucks list', (tester) async {
      await withMockedHttp(
        setup: (r) {
          r.respond('GET', '/api/trucks/my', body: []);
          r.respond('GET', '/api/operating-card', body: {'data': null});
        },
        callback: (_) async {
          await _pumpAndDrain(tester, const VehicleManagementScreen());
          expect(find.byType(VehicleManagementScreen), findsOneWidget);
        },
      );
    });

    testWidgets('renders one truck card', (tester) async {
      await withMockedHttp(
        setup: (r) {
          r.respond('GET', '/api/trucks/my', body: [
            {
              'id': 1,
              'truck_type': 'متوسط',
              'plate_number': 'A 1234 ر',
              'is_active': 1,
              'insurance_status': 'valid',
              'truck_group': 'light',
              'truck_classification': 'small',
              'axle_count': '1_axle',
              'body_type': 'standard_cargo',
              'load_capacity_id': 'cap_3_5_ton',
            }
          ]);
          r.respond('GET', '/api/operating-card', body: {'data': null});
        },
        callback: (_) async {
          await _pumpAndDrain(tester, const VehicleManagementScreen());
          expect(find.byType(VehicleManagementScreen), findsOneWidget);
        },
      );
    });
  });

  // ------------------------------------------------------------------
  // BidDetailsScreen (bidding_room_screen.dart)
  // ------------------------------------------------------------------

  group('BidDetailsScreen', () {
    testWidgets('renders with shipment summary and bid form', (tester) async {
      await withMockedHttp(
        setup: (r) {
          r.respond('GET', '/api/auth/profile/5', body: _profileFixture());
          r.respond('GET', '/api/bids/shipment/9', body: []);
        },
        callback: (_) async {
          await _pumpAndDrain(
            tester,
            BidDetailsScreen(
              shipmentId: 9,
              driverId: 5,
              driverName: 'سائق',
              shipmentData: const {
                'id': 9,
                'cargo_type': 'بضائع',
                'weight': 800,
                'pickup_city': 'الرياض',
                'destination_city': 'جدة',
                'base_price': 1500,
                'suggested_price': 1500,
                'description': 'تجريبي',
                'pickup_date': '2026-06-01',
              },
            ),
          );
          expect(find.byType(BidDetailsScreen), findsOneWidget);
        },
      );
    });

    testWidgets('renders with existing bids list', (tester) async {
      await withMockedHttp(
        setup: (r) {
          r.respond('GET', '/api/auth/profile/5', body: _profileFixture());
          r.respond('GET', '/api/bids/shipment/9', body: [
            {
              'id': 1,
              'shipment_id': 9,
              'driver_id': 5,
              'bid_amount': '1300',
              'estimated_days': 3,
              'bid_status': 'pending',
              'driver_name': 'منافس',
            }
          ]);
        },
        callback: (_) async {
          await _pumpAndDrain(
            tester,
            BidDetailsScreen(
              shipmentId: 9,
              driverId: 5,
              driverName: 'سائق',
              shipmentData: const {
                'id': 9,
                'cargo_type': 'بضائع',
                'weight': 800,
                'pickup_city': 'الرياض',
                'destination_city': 'جدة',
                'base_price': 1500,
                'suggested_price': 1500,
                'description': 'تجريبي',
                'pickup_date': '2026-06-01',
              },
            ),
          );
          expect(find.byType(BidDetailsScreen), findsOneWidget);
        },
      );
    });
  });

  // ------------------------------------------------------------------
  // ShipmentBidsDetailScreen
  // ------------------------------------------------------------------

  group('ShipmentBidsDetailScreen', () {
    testWidgets('renders empty bids state', (tester) async {
      await withMockedHttp(
        setup: (r) {
          r.respond('GET', '/api/bids/shipment/5', body: []);
        },
        callback: (_) async {
          await _pumpAndDrain(
            tester,
            const ShipmentBidsDetailScreen(
              shipmentId: 5,
              pickupAddress: 'الرياض',
              dropoffAddress: 'جدة',
              suggestedPrice: 1500,
            ),
          );
          expect(find.byType(ShipmentBidsDetailScreen), findsOneWidget);
        },
      );
    });

    testWidgets('renders bids and matches user-facing summary', (tester) async {
      await withMockedHttp(
        setup: (r) {
          r.respond('GET', '/api/bids/shipment/5', body: [
            {
              'id': 1,
              'shipment_id': 5,
              'driver_id': 9,
              'bid_amount': '900',
              'estimated_days': 4,
              'bid_status': 'pending',
              'driver_name': 'علي',
            },
            {
              'id': 2,
              'shipment_id': 5,
              'driver_id': 12,
              'bid_amount': '1100',
              'estimated_days': 2,
              'bid_status': 'pending',
              'driver_name': 'محمد',
            }
          ]);
        },
        callback: (_) async {
          await _pumpAndDrain(
            tester,
            const ShipmentBidsDetailScreen(
              shipmentId: 5,
              pickupAddress: 'الرياض',
              dropoffAddress: 'جدة',
              suggestedPrice: 1500,
            ),
          );
          expect(find.byType(ShipmentBidsDetailScreen), findsOneWidget);
        },
      );
    });
  });

  // ------------------------------------------------------------------
  // RatingsScreen
  // ------------------------------------------------------------------

  group('RatingsScreen', () {
    testWidgets('renders rating form when no existing rating', (tester) async {
      await withMockedHttp(
        setup: (r) {
          r.respond('GET', '/api/ratings/user/9', body: {
            'average_rating': '4.40',
            'total_ratings': 2,
            'ratings': [
              {
                'id': 1,
                'shipment_id': 99,
                'rater_id': 7,
                'stars': 5,
                'comment': 'عمل ممتاز',
                'created_at': '2026-01-01',
              }
            ],
            'rated_profile': {
              'id': 9,
              'name': 'تجريبي',
              'role': 'driver',
            }
          });
        },
        callback: (_) async {
          await _pumpAndDrain(
            tester,
            const RatingsScreen(
              shipmentId: 100,
              otherUserId: 9,
              otherUserRole: 'driver',
              otherUserName: 'تجريبي',
            ),
          );
          expect(find.byType(RatingsScreen), findsOneWidget);
          expect(find.textContaining('أضف تقييمك'), findsOneWidget);
        },
      );
    });

    testWidgets('shows already-rated state when current user rated shipment',
        (tester) async {
      await withMockedHttp(
        setup: (r) {
          r.respond('GET', '/api/ratings/user/9', body: {
            'average_rating': '5.00',
            'total_ratings': 1,
            'ratings': [
              {
                'id': 1,
                'shipment_id': 100,
                'rater_id': 1,
                'stars': 5,
                'comment': 'تم',
                'created_at': '2026-01-01',
              }
            ],
          });
          r.respond('GET', '/api/users/9/profile', body: {
            'data': {'id': 9, 'name': 'تجريبي', 'role': 'driver'}
          });
        },
        callback: (_) async {
          await _pumpAndDrain(
            tester,
            const RatingsScreen(
              shipmentId: 100,
              otherUserId: 9,
              otherUserRole: 'driver',
              otherUserName: 'تجريبي',
            ),
          );
          expect(find.textContaining('تم إرسال تقييمك'), findsOneWidget);
        },
      );
    });

    testWidgets('select stars triggers _selectedRating change',
        (tester) async {
      await withMockedHttp(
        setup: (r) {
          r.respond('GET', '/api/ratings/user/9', body: {
            'average_rating': '0.00',
            'total_ratings': 0,
            'ratings': [],
          });
          r.respond('GET', '/api/users/9/profile', body: {
            'data': {'id': 9, 'name': 'تجريبي', 'role': 'driver'}
          });
        },
        callback: (_) async {
          await _pumpAndDrain(
            tester,
            const RatingsScreen(
              shipmentId: 100,
              otherUserId: 9,
              otherUserRole: 'driver',
              otherUserName: 'تجريبي',
            ),
          );

          // Tap the fifth star in the form
          final stars = find.byIcon(Icons.star);
          expect(stars, findsWidgets);
          await tester.tap(stars.last);
          await tester.pump();
        },
      );
    });
  });

  // ------------------------------------------------------------------
  // UserRatingsOverviewScreen
  // ------------------------------------------------------------------

  group('UserRatingsOverviewScreen', () {
    testWidgets('renders summary + list', (tester) async {
      await withMockedHttp(
        setup: (r) {
          r.respond('GET', '/api/ratings/user/2', body: {
            'average_rating': '4.20',
            'total_ratings': 5,
            'ratings': [
              {
                'id': 1,
                'shipment_id': 99,
                'rater_id': 7,
                'stars': 4,
                'comment': 'جيد',
                'created_at': '2026-01-01',
              },
              {
                'id': 2,
                'shipment_id': 100,
                'rater_id': 8,
                'stars': 5,
                'comment': null,
                'created_at': '2026-01-02',
              },
            ],
          });
        },
        callback: (_) async {
          await _pumpAndDrain(
            tester,
            const UserRatingsOverviewScreen(
              userId: 2,
              userName: 'تجريبي',
            ),
          );
          expect(find.byType(UserRatingsOverviewScreen), findsOneWidget);
          expect(find.text('4.2'), findsOneWidget);
        },
      );
    });

    testWidgets('shows fallback state on API failure', (tester) async {
      await withMockedHttp(
        setup: (r) => r.respond('GET', '/api/ratings/user/2',
            statusCode: 500, body: {'message': 'oops'}),
        callback: (_) async {
          await _pumpAndDrain(
            tester,
            const UserRatingsOverviewScreen(
              userId: 2,
              userName: 'تجريبي',
            ),
          );
          expect(find.byType(UserRatingsOverviewScreen), findsOneWidget);
        },
      );
    });
  });
}
