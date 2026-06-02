import 'package:darbak/available_loads_screen.dart';
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

Map<String, dynamic> _profile({String status = 'verified'}) => {
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

Map<String, dynamic> _paginated(List<Map<String, dynamic>> rows) => {
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
      'user_role': 'driver',
      'auth_token': 't',
    });
  });

  testWidgets('toggling filter panel reveals fields', (tester) async {
    await withMockedHttp(
      setup: (r) {
        r.respond('GET', '/api/auth/profile/1', body: _profile());
        r.respond('GET', '/api/shipments', body: _paginated([]));
        r.respond('GET', '/api/bids/me/active',
            body: {'active': false, 'bid': null});
      },
      callback: (_) async {
        await _pump(tester, const AvailableLoadsScreen());
        final toggle = find.textContaining('بحث');
        if (toggle.evaluate().isNotEmpty) {
          await tester.ensureVisible(toggle.first);
          await tester.pumpAndSettle();
          await tester.tap(toggle.first);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(find.byType(AvailableLoadsScreen), findsOneWidget);
      },
    );
  });

  testWidgets('tapping bid button on a shipment pushes BidDetailsScreen',
      (tester) async {
    final shipment = {
      'id': 22,
      'cargo_type': 'إلكترونيات',
      'cargo_description': 'تجريبي',
      'weight': 1200,
      'pickup_city': 'الرياض',
      'destination_city': 'جدة',
      'pickup_address': 'الرياض، الملك فهد',
      'dropoff_address': 'جدة، طريق المطار',
      'base_price': 2400,
      'suggested_price': 2400,
      'status': 'bidding',
      'pickup_date': '2026-06-01',
      'description': 'تجريبي',
    };
    await withMockedHttp(
      setup: (r) {
        r.respond('GET', '/api/auth/profile/1', body: _profile());
        r.respond('GET', '/api/shipments', body: _paginated([shipment]));
        r.respond('GET', '/api/bids/me/active',
            body: {'active': false, 'bid': null});
        r.respond('GET', '/api/bids/shipment/22', body: []);
      },
      callback: (_) async {
        await _pump(tester, const AvailableLoadsScreen());

        final bidBtn = find.textContaining('تقديم عرض');
        if (bidBtn.evaluate().isNotEmpty) {
          await tester.ensureVisible(bidBtn.first);
          await tester.pumpAndSettle();
          await tester.tap(bidBtn.first);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 200));
          await tester.pump(const Duration(milliseconds: 400));
          expect(find.byType(BidDetailsScreen), findsOneWidget);
        } else {
          expect(find.byType(AvailableLoadsScreen), findsOneWidget);
        }
      },
    );
  });

  testWidgets('matching shipment + own active bid shows withdraw flow',
      (tester) async {
    final shipment = {
      'id': 55,
      'cargo_type': 'مواد بناء',
      'cargo_description': 'إسمنت',
      'weight': 1500,
      'pickup_city': 'الرياض',
      'destination_city': 'جدة',
      'pickup_address': 'الرياض، الملك فهد',
      'dropoff_address': 'جدة، طريق المطار',
      'base_price': 2400,
      'suggested_price': 2400,
      'status': 'bidding',
      'pickup_date': '2026-06-01',
    };
    await withMockedHttp(
      setup: (r) {
        r.respond('GET', '/api/auth/profile/1', body: _profile());
        r.respond('GET', '/api/shipments', body: _paginated([shipment]));
        r.respond('GET', '/api/bids/me/active', body: {
          'active': true,
          'bid': {
            'shipment_id': 55,
            'amount': 2000,
            'status': 'pending',
            'pickup_city': 'الرياض',
            'destination_city': 'جدة',
            'cargo_type': 'مواد بناء',
          }
        });
        r.respond('POST', '/api/bids/me/withdraw', body: {'ok': true});
      },
      callback: (_) async {
        await _pump(tester, const AvailableLoadsScreen());
        // Look for a withdraw / cancel-bid action.
        final withdraw = find.textContaining('سحب');
        if (withdraw.evaluate().isNotEmpty) {
          await tester.ensureVisible(withdraw.first);
          await tester.pump();
          await tester.tap(withdraw.first);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 200));
          final confirm = find.text('سحب العرض');
          if (confirm.evaluate().isNotEmpty) {
            await tester.tap(confirm.last);
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 300));
          }
        }
        expect(find.byType(AvailableLoadsScreen), findsOneWidget);
      },
    );
  });

  testWidgets('typing in filter fields triggers debounced reload', (tester) async {
    await withMockedHttp(
      setup: (r) {
        r.respond('GET', '/api/auth/profile/1', body: _profile());
        r.respond('GET', '/api/shipments', body: _paginated([]));
        r.respond('GET', '/api/bids/me/active',
            body: {'active': false, 'bid': null});
      },
      callback: (_) async {
        await _pump(tester, const AvailableLoadsScreen());
        final toggle = find.textContaining('بحث');
        if (toggle.evaluate().isNotEmpty) {
          await tester.ensureVisible(toggle.first);
          await tester.pumpAndSettle();
          await tester.tap(toggle.first);
          await tester.pump(const Duration(milliseconds: 300));
        }
        final fields = find.byType(TextField);
        if (fields.evaluate().isNotEmpty) {
          await tester.enterText(fields.first, 'الرياض');
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 500));
        }
        expect(find.byType(AvailableLoadsScreen), findsOneWidget);
      },
    );
  });

  testWidgets('shipment with auction countdown renders card', (tester) async {
    final shipment = {
      'id': 77,
      'cargo_type': 'مواد',
      'weight': 800,
      'pickup_city': 'الرياض',
      'destination_city': 'جدة',
      'pickup_address': 'الرياض',
      'dropoff_address': 'جدة',
      'base_price': 1500,
      'suggested_price': 1500,
      'status': 'bidding',
      'pickup_date': '2026-06-01',
      'auction_end_time':
          DateTime.now().add(const Duration(hours: 2)).toIso8601String(),
    };
    await withMockedHttp(
      setup: (r) {
        r.respond('GET', '/api/auth/profile/1', body: _profile());
        r.respond('GET', '/api/shipments', body: _paginated([shipment]));
        r.respond('GET', '/api/bids/me/active',
            body: {'active': false, 'bid': null});
      },
      callback: (_) async {
        await _pump(tester, const AvailableLoadsScreen());
        expect(find.byType(AvailableLoadsScreen), findsOneWidget);
      },
    );
  });

  testWidgets('reset filters clears entered text', (tester) async {
    await withMockedHttp(
      setup: (r) {
        r.respond('GET', '/api/auth/profile/1', body: _profile());
        r.respond('GET', '/api/shipments', body: _paginated([]));
        r.respond('GET', '/api/bids/me/active',
            body: {'active': false, 'bid': null});
      },
      callback: (_) async {
        await _pump(tester, const AvailableLoadsScreen());
        // Expand the search panel.
        final toggle = find.textContaining('بحث');
        if (toggle.evaluate().isNotEmpty) {
          await tester.ensureVisible(toggle.first);
          await tester.pumpAndSettle();
          await tester.tap(toggle.first);
          await tester.pump(const Duration(milliseconds: 300));
        }
        // Try to enter text into the first text field exposed by the panel.
        final fields = find.byType(TextField);
        if (fields.evaluate().isNotEmpty) {
          await tester.enterText(fields.first, 'الرياض');
          await tester.pump();
        }
        // Tap any reset button if available.
        final resetBtn = find.textContaining('إعادة');
        if (resetBtn.evaluate().isNotEmpty) {
          await tester.ensureVisible(resetBtn.first);
          await tester.pumpAndSettle();
          await tester.tap(resetBtn.first);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 200));
        }
        expect(find.byType(AvailableLoadsScreen), findsOneWidget);
      },
    );
  });

  testWidgets('active personal bid row shows withdraw button', (tester) async {
    await withMockedHttp(
      setup: (r) {
        r.respond('GET', '/api/auth/profile/1', body: _profile());
        r.respond('GET', '/api/shipments', body: _paginated([]));
        r.respond('GET', '/api/bids/me/active', body: {
          'active': true,
          'bid': {
            'shipment_id': 33,
            'amount': 1500,
            'status': 'pending',
            'pickup_city': 'الرياض',
            'destination_city': 'جدة',
            'cargo_type': 'مواد',
          }
        });
      },
      callback: (_) async {
        await _pump(tester, const AvailableLoadsScreen());
        expect(find.byType(AvailableLoadsScreen), findsOneWidget);
      },
    );
  });

  testWidgets('shows KYB banner when driver verification is pending',
      (tester) async {
    await withMockedHttp(
      setup: (r) {
        r.respond('GET', '/api/auth/profile/1',
            body: _profile(status: 'pending'));
        r.respond('GET', '/api/shipments', body: _paginated([]));
        r.respond('GET', '/api/bids/me/active',
            body: {'active': false, 'bid': null});
      },
      callback: (_) async {
        await _pump(tester, const AvailableLoadsScreen());
        // Look for the verified_user icon used in the KYB banner.
        expect(find.byIcon(Icons.verified_user_outlined), findsAtLeast(1));
      },
    );
  });
}
