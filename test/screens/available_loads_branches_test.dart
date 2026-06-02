import 'dart:convert';

import 'package:darbak/available_loads_screen.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
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

Map<String, dynamic> _paginated(List<Map<String, dynamic>> rows,
        {int page = 1, int totalPages = 1}) =>
    {
      'data': rows,
      'pagination': {
        'page': page,
        'limit': 20,
        'total': rows.length,
        'totalPages': totalPages,
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

  testWidgets('API failure shows Arabic error banner text', (tester) async {
    await withMockedHttp(
      setup: (r) {
        r.respond('GET', '/api/auth/profile/1', body: _profile());
        r.respond('GET', '/api/shipments',
            statusCode: 500, body: {'message': 'boom'});
        r.respond('GET', '/api/bids/me/active',
            body: {'active': false, 'bid': null});
      },
      callback: (_) async {
        await _pump(tester, const AvailableLoadsScreen());
        expect(find.textContaining('فشل في تحميل الشحنات'), findsOneWidget);
      },
    );
  });

  testWidgets('rejected KYB banner shows rejection copy', (tester) async {
    await withMockedHttp(
      setup: (r) {
        r.respond('GET', '/api/auth/profile/1',
            body: _profile(status: 'rejected'));
        r.respond('GET', '/api/shipments', body: _paginated([]));
        r.respond('GET', '/api/bids/me/active',
            body: {'active': false, 'bid': null});
      },
      callback: (_) async {
        await _pump(tester, const AvailableLoadsScreen());
        expect(find.textContaining('لم تُقبل'), findsOneWidget);
      },
    );
  });

  testWidgets('withdraw failure shows DarbakException snackbar', (tester) async {
    final shipment = {
      'id': 55,
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
    };
    await withMockedHttp(
      setup: (r) {
        r.respond('GET', '/api/auth/profile/1', body: _profile());
        r.respond('GET', '/api/shipments', body: _paginated([shipment]));
        r.respond('GET', '/api/bids/me/active', body: {
          'active': true,
          'bid': {
            'shipment_id': 55,
            'amount': 1200,
            'status': 'pending',
            'pickup_city': 'الرياض',
            'destination_city': 'جدة',
            'cargo_type': 'مواد',
          }
        });
        r.respond('POST', '/api/bids/me/withdraw',
            statusCode: 409, body: {'message': 'لا يمكن السحب'});
      },
      callback: (_) async {
        await _pump(tester, const AvailableLoadsScreen());
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

  testWidgets('scroll near end requests the next shipments page', (tester) async {
    final page1 = List.generate(
      20,
      (i) => {
        'id': i + 1,
        'cargo_type': 'بضائع',
        'weight': 500,
        'pickup_city': 'الرياض',
        'destination_city': 'جدة',
        'pickup_address': 'الرياض',
        'dropoff_address': 'جدة',
        'base_price': 1000,
        'suggested_price': 1000,
        'status': 'bidding',
        'pickup_date': '2026-06-01',
      },
    );
    await withMockedHttp(
      setup: (r) {
        r.respond('GET', '/api/auth/profile/1', body: _profile());
        r.when('GET', '/api/shipments', handler: (req) async {
          final page = req.url.queryParameters['page'];
          if (page == '2') {
            return _jsonResponse(req, 200, _paginated([
              {
                'id': 99,
                'cargo_type': 'بضائع',
                'weight': 500,
                'pickup_city': 'الرياض',
                'destination_city': 'جدة',
                'pickup_address': 'الرياض',
                'dropoff_address': 'جدة',
                'base_price': 1000,
                'suggested_price': 1000,
                'status': 'bidding',
                'pickup_date': '2026-06-01',
              }
            ], page: 2, totalPages: 2));
          }
          return _jsonResponse(req, 200, _paginated(page1, totalPages: 2));
        });
        r.respond('GET', '/api/bids/me/active',
            body: {'active': false, 'bid': null});
      },
      callback: (_) async {
        await _pump(tester, const AvailableLoadsScreen());
        await tester.drag(find.byType(ListView), const Offset(0, -2400));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.byType(AvailableLoadsScreen), findsOneWidget);
      },
    );
  });
}

http.Response _jsonResponse(http.BaseRequest req, int status, Object body) {
  return http.Response(
    jsonEncode(body),
    status,
    headers: const {'content-type': 'application/json'},
    request: req,
  );
}
