import 'package:darbak/auth_screens.dart';
import 'package:darbak/driver_home.dart';
import 'package:darbak/shipper_home.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/http_mock.dart';

Widget _app(Widget home) => MaterialApp(home: home);

void main() {
  testWidgets('Splash navigates to LoginScreen when logged out', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      _app(const SplashScreen(completeImmediatelyForTest: true)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('Splash navigates to DriverHomeScreen for saved driver session',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'is_logged_in': true,
      'user_role': 'driver',
      'user_id': 1,
      'auth_token': 't',
    });
    await withMockedHttp(
      setup: (r) {
        r.respond('GET', '/api/shipments/driver/active', body: []);
        r.respond('GET', '/api/auth/profile/1', body: {
          'id': 1,
          'role': 'driver',
          'verification_status': 'verified',
        });
        r.respond('GET', '/api/shipments', body: {
          'data': [],
          'pagination': {'page': 1, 'limit': 20, 'total': 0, 'totalPages': 0},
        });
        r.respond('GET', '/api/bids/me/active', body: {'active': false});
        r.respond('GET', '/api/shipments/driver', body: []);
        r.respond('GET', '/api/chat/conversations/me', body: []);
        r.respond('GET', '/api/operating-card', body: {'data': null});
        r.respond('GET', '/api/trucks/my', body: []);
        r.respond('GET', '/api/profile/me', body: {
          'data': {'id': 1, 'role': 'driver', 'verification_status': 'verified'}
        });
      },
      callback: (_) async {
        await tester.pumpWidget(
          _app(const SplashScreen(completeImmediatelyForTest: true)),
        );
        await tester.pump();
        for (var i = 0; i < 12; i++) {
          await tester.pump(const Duration(milliseconds: 80));
        }
        expect(find.byType(DriverHomeScreen), findsOneWidget);
      },
    );
  });

  testWidgets('Splash navigates to ShipperHomeScreen for saved shipper session',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'is_logged_in': true,
      'user_role': 'shipper',
      'user_id': 1,
      'auth_token': 't',
    });
    await withMockedHttp(
      setup: (r) {
        r.respond('GET', '/api/profile/me', body: {
          'data': {'id': 1, 'role': 'shipper', 'verification_status': 'verified'}
        });
        r.respond('GET', '/api/shipments', body: []);
        r.respond('GET', '/api/chat/conversations/me', body: []);
        r.respond('GET', '/api/notifications/user/1',
            body: {'data': [], 'unread_count': 0});
      },
      callback: (_) async {
        await tester.pumpWidget(
          _app(const SplashScreen(completeImmediatelyForTest: true)),
        );
        await tester.pump();
        for (var i = 0; i < 12; i++) {
          await tester.pump(const Duration(milliseconds: 80));
        }
        expect(find.byType(ShipperHomeScreen), findsOneWidget);
      },
    );
  });
}
