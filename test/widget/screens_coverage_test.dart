import 'dart:convert';

import 'package:darbak/api_service.dart';
import 'package:darbak/app_theme.dart';
import 'package:darbak/app_widgets.dart';
import 'package:darbak/auth_screens.dart';
import 'package:darbak/available_loads_screen.dart';
import 'package:darbak/bidding_room_screen.dart';
import 'package:darbak/driver_home.dart';
import 'package:darbak/job_tracking_screen.dart';
import 'package:darbak/main.dart';
import 'package:darbak/ratings_screen.dart';
import 'package:darbak/shipment_bids_detail_screen.dart';
import 'package:darbak/shipment_screens.dart';
import 'package:darbak/shipper_home.dart';
import 'package:darbak/trip_screens.dart';
import 'package:darbak/vehicle_management_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../unit/api_service_test.mocks.dart';

http.Response _utf8(String body, [int code = 200]) {
  return http.Response.bytes(utf8.encode(body), code);
}

/// Stubs the HTTP calls made when opening driver/shipper shells and related flows.
void _registerWideHttpStubs(MockClient mock) {
  when(mock.get(any, headers: anyNamed('headers'))).thenAnswer((inv) async {
    final uri = inv.positionalArguments[0] as Uri;
    final p = uri.path;

    if (p.contains('/admin/get-signed-url')) {
      return _utf8(jsonEncode({'signedUrl': 'https://signed.example/pod.jpg'}));
    }
    if (p.contains('/notifications/user/')) {
      return _utf8(jsonEncode({'notifications': <Map<String, dynamic>>[]}));
    }
    if (p.contains('/chat/conversations/me')) {
      return _utf8('[]');
    }
    if (p.contains('/shipments/driver/active')) {
      return _utf8('[]');
    }
    if (p.endsWith('/shipments/driver')) {
      return _utf8('[]');
    }
    if (p.contains('/trucks/my')) {
      return _utf8('[]');
    }
    if (p.contains('/ratings/user/')) {
      return _utf8(jsonEncode({'avg': 4.5, 'count': 2}));
    }
    if (p.contains('/bids/shipment/')) {
      return _utf8('[]');
    }
    if (p.contains('/shipment-status/') && p.contains('/history')) {
      return _utf8(
        jsonEncode({
          'history': <Map<String, dynamic>>[
            {'photo_path': 'https://cdn.example/epod.jpg'},
          ],
        }),
      );
    }
    if (p.contains('/chat/') && !p.contains('conversations')) {
      return _utf8('[]');
    }
    if (p.contains('/shipments/') && p.contains('/contract')) {
      return _utf8(jsonEncode({'url': 'https://bucket.s3.amazonaws.com/c.pdf?X-Amz-Signature=1'}));
    }
    if (RegExp(r'^/api/shipments/\d+$').hasMatch(p)) {
      return _utf8(
        jsonEncode({
          'id': 1,
          'status': 'delivered',
          'pickup_address': 'Riyadh, SA',
          'dropoff_address': 'Jeddah, SA',
          'pickup_lat': 24.7,
          'pickup_lng': 46.7,
          'dropoff_lat': 21.5,
          'dropoff_lng': 39.2,
          'shipper_id': 2,
          'driver_id': 1,
        }),
      );
    }
    if (p == '/api/shipments' || (p.endsWith('/shipments') && !p.contains('driver'))) {
      return _utf8('[]');
    }
    if (p.contains('/auth/profile/')) {
      return _utf8(
        jsonEncode({
          'id': 1,
          'full_name': 'Test',
          'email': 't@t.com',
          'phone': '0511111111',
          'license_no': 'L1',
          'expiry_date': DateTime.now().add(const Duration(days: 365)).toIso8601String(),
          'rating': '4',
          'completed_trips': '1',
          'total_earnings': '100',
        }),
      );
    }
    return _utf8('{}', 404);
  });

  when(mock.post(any, headers: anyNamed('headers'), body: anyNamed('body')))
      .thenAnswer((_) async => _utf8('{}', 200));
  when(mock.post(any, headers: anyNamed('headers'))).thenAnswer((_) async => _utf8('{}', 200));
  when(mock.patch(any, headers: anyNamed('headers'), body: anyNamed('body')))
      .thenAnswer((_) async => _utf8('{}', 200));
}

Future<void> _pumpLarge(
  WidgetTester tester,
  Widget home, {
  bool shipperList = false,
}) async {
  tester.view.physicalSize = const Size(1080, 2800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  SharedPreferences.setMockInitialValues({
    'user_id': 1,
    'user_name': 'Tester',
    'user_role': shipperList ? 'shipper' : 'driver',
    'auth_token': 'tok',
  });

  await tester.pumpWidget(
    MaterialApp(
      theme: DarbakTheme.lightTheme,
      home: home,
    ),
  );
}

void main() {
  group('Screen smoke coverage', () {
    late MockClient mockClient;

    setUp(() {
      mockClient = MockClient();
      ApiService.setHttpClientForTests(mockClient);
    });

    tearDown(() {
      ApiService.resetHttpClientForTests();
    });

    testWidgets('ChooseRoleScreen shows role selection', (tester) async {
      await _pumpLarge(tester, const ChooseRoleScreen());
      expect(find.textContaining('اختر نوع حسابك'), findsWidgets);
    });

    testWidgets('SplashScreen builds', (tester) async {
      await _pumpLarge(tester, const SplashScreen());
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('DarbakApp builds', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(const DarbakApp());
      await tester.pump();
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('DriverShipmentsMarketScreen loads list UI', (tester) async {
      when(
        mockClient.get(
          Uri.parse('http://10.0.2.2:5000/api/shipments'),
          headers: anyNamed('headers'),
        ),
      ).thenAnswer((_) async => _utf8('[]'));

      await _pumpLarge(tester, const DriverShipmentsMarketScreen());
      await tester.pumpAndSettle();
      expect(find.text('لا توجد شحنات متاحة حالياً'), findsOneWidget);
    });

    testWidgets('VehicleManagementScreen shows truck management', (tester) async {
      when(
        mockClient.get(
          Uri.parse('http://10.0.2.2:5000/api/trucks/my'),
          headers: anyNamed('headers'),
        ),
      ).thenAnswer((_) async => _utf8('[]'));

      await _pumpLarge(tester, const VehicleManagementScreen());
      await tester.pumpAndSettle();
      expect(find.textContaining('الشاحنة'), findsWidgets);
    });

    testWidgets('ShipperHomeScreen first tab loads', (tester) async {
      when(
        mockClient.get(
          Uri.parse('http://10.0.2.2:5000/api/shipments'),
          headers: anyNamed('headers'),
        ),
      ).thenAnswer(
        (_) async => _utf8(
          jsonEncode([
            {'id': 10, 'shipper_id': 1, 'status': 'bidding'},
          ]),
        ),
      );

      await _pumpLarge(tester, const ShipperHomeScreen(), shipperList: true);
      await tester.pumpAndSettle();
      expect(find.text('شحناتي'), findsWidgets);
    });

    testWidgets('ShipperContractScreen shows contract copy', (tester) async {
      await _pumpLarge(tester, const ShipperContractScreen());
      expect(find.textContaining('العقد الإلكتروني'), findsWidgets);
    });

    testWidgets('ShipperBidsPlaceholderScreen builds', (tester) async {
      await _pumpLarge(tester, const ShipperBidsPlaceholderScreen());
      expect(find.textContaining('عروض السائقين'), findsWidgets);
    });

    testWidgets('BidDetailsScreen shows shipment summary', (tester) async {
      when(
        mockClient.get(
          Uri.parse('http://10.0.2.2:5000/api/bids/shipment/1'),
          headers: anyNamed('headers'),
        ),
      ).thenAnswer((_) async => _utf8('[]'));
      when(
        mockClient.get(
          Uri.parse('http://10.0.2.2:5000/api/auth/profile/2'),
          headers: anyNamed('headers'),
        ),
      ).thenAnswer(
        (_) async => _utf8(
          jsonEncode({
            'id': 2,
            'expiry_date': DateTime.now().add(const Duration(days: 400)).toIso8601String(),
          }),
        ),
      );

      await _pumpLarge(
        tester,
        BidDetailsScreen(
          shipmentId: 1,
          shipmentData: const {
            'base_price': 1000,
            'pickup_address': 'A,B',
            'dropoff_address': 'C,D',
          },
          driverId: 2,
          driverName: 'سائق',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('ملخص الشحنة'), findsOneWidget);
    });

    testWidgets('JobTrackingScreen shows timeline after load', (tester) async {
      when(
        mockClient.get(
          Uri.parse('http://10.0.2.2:5000/api/shipments/1'),
          headers: anyNamed('headers'),
        ),
      ).thenAnswer(
        (_) async => _utf8(
          jsonEncode({
            'id': 1,
            'status': 'delivered',
            'pickup_address': 'Riyadh',
            'dropoff_address': 'Jeddah',
            'pickup_lat': 24,
            'pickup_lng': 46,
            'dropoff_lat': 21,
            'dropoff_lng': 39,
          }),
        ),
      );
      when(
        mockClient.get(
          Uri.parse('http://10.0.2.2:5000/api/shipment-status/1/history'),
          headers: anyNamed('headers'),
        ),
      ).thenAnswer(
        (_) async => _utf8(
          jsonEncode({
            'history': [
              {'photo_path': 'https://cdn.example/pod.jpg'},
            ],
          }),
        ),
      );

      await _pumpLarge(
        tester,
        JobTrackingScreen(
          shipmentId: 1,
          shipmentData: const {
            'id': 1,
            'status': 'delivered',
            'pickup_address': 'Riyadh',
            'dropoff_address': 'Jeddah',
            'pickup_lat': 24,
            'pickup_lng': 46,
            'dropoff_lat': 21,
            'dropoff_lng': 39,
          },
        ),
      );
      // Repeating pulse animation prevents pumpAndSettle from completing.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('متابعة الرحلة'), findsWidgets);
    });

    testWidgets('AvailableLoadsScreen shows empty market', (tester) async {
      when(
        mockClient.get(
          Uri.parse('http://10.0.2.2:5000/api/shipments'),
          headers: anyNamed('headers'),
        ),
      ).thenAnswer((_) async => _utf8('[]'));
      when(
        mockClient.get(
          Uri.parse('http://10.0.2.2:5000/api/auth/profile/1'),
          headers: anyNamed('headers'),
        ),
      ).thenAnswer(
        (_) async => _utf8(
          jsonEncode({'full_name': 'Tester', 'rating': '4', 'completed_trips': '0', 'total_earnings': '0'}),
        ),
      );

      await _pumpLarge(tester, const AvailableLoadsScreen());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('لا توجد شحنات متاحة حالياً'), findsOneWidget);
    });

    testWidgets('ShipmentBidsDetailScreen loads bids list', (tester) async {
      when(
        mockClient.get(
          Uri.parse('http://10.0.2.2:5000/api/bids/shipment/5'),
          headers: anyNamed('headers'),
        ),
      ).thenAnswer((_) async => _utf8('[]'));

      await _pumpLarge(
        tester,
        const ShipmentBidsDetailScreen(shipmentId: 5, shipmentTitle: '#5'),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('عروض'), findsWidgets);
    });

    testWidgets('TripTrackingScreen builds', (tester) async {
      await _pumpLarge(
        tester,
        const TripTrackingScreen(
          shipmentId: '1',
          driverName: 'س',
          driverRating: '4',
          driverPhone: '0512345678',
        ),
      );
      expect(find.textContaining('تتبع الرحلة'), findsOneWidget);
    });

    testWidgets('ProofOfDeliveryScreen builds', (tester) async {
      await _pumpLarge(tester, const ProofOfDeliveryScreen(shipmentId: '1'));
      expect(find.textContaining('إثبات التسليم'), findsWidgets);
    });

    testWidgets('PenaltyScreen builds', (tester) async {
      await _pumpLarge(
        tester,
        PenaltyScreen(
          shipmentData: {
            'shipment_id': 1,
            'bid_amount': 1000,
            'expected_delivery_at': DateTime.now()
                .add(const Duration(days: 2))
                .toIso8601String(),
            'delivered_at': DateTime.now().toIso8601String(),
          },
        ),
      );
      expect(find.textContaining('تفاصيل الدفع'), findsOneWidget);
    });

    testWidgets('ChatScreen loads messages', (tester) async {
      when(
        mockClient.get(
          Uri.parse('http://10.0.2.2:5000/api/shipments/1'),
          headers: anyNamed('headers'),
        ),
      ).thenAnswer(
        (_) async => _utf8(jsonEncode({'shipper_id': 2, 'driver_id': 1})),
      );
      when(
        mockClient.get(
          Uri.parse('http://10.0.2.2:5000/api/chat/1'),
          headers: anyNamed('headers'),
        ),
      ).thenAnswer((_) async => _utf8('[]'));

      await _pumpLarge(
        tester,
        const ChatScreen(
          shipmentId: '1',
          otherUser: 'طرف',
          otherUserId: 2,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('طرف'), findsOneWidget);
    });

    testWidgets('RatingsScreen loads', (tester) async {
      when(
        mockClient.get(
          Uri.parse('http://10.0.2.2:5000/api/ratings/user/3'),
          headers: anyNamed('headers'),
        ),
      ).thenAnswer((_) async => _utf8(jsonEncode({'avg': 4, 'reviews': []})));

      await _pumpLarge(
        tester,
        const RatingsScreen(
          shipmentId: 1,
          otherUserId: 3,
          otherUserRole: 'driver',
          otherUserName: 'سائق',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('تقييم'), findsWidgets);
    });

    testWidgets('DriverHomeScreen tabs switch without crash', (tester) async {
      _registerWideHttpStubs(mockClient);

      await _pumpLarge(tester, const DriverHomeScreen());
      await tester.pumpAndSettle();

      await tester.tap(find.text('رحلاتي'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('الرسائل'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('حسابي'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('السوق'));
      await tester.pumpAndSettle();
    });

    testWidgets('app_widgets buttons build', (tester) async {
      await _pumpLarge(
        tester,
        Scaffold(
          body: Column(
            children: [
              DarbakOutlinedButton(label: 'خروج', onPressed: () {}),
              const DarbakSectionTitle(title: 'عنوان', subtitle: 'وصف'),
            ],
          ),
        ),
      );
      expect(find.text('خروج'), findsOneWidget);
      expect(find.text('عنوان'), findsOneWidget);
    });
  });
}
