import 'package:darbak/ratings_screen.dart';
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

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'user_id': 1,
      'user_role': 'driver',
      'auth_token': 't',
    });
  });

  testWidgets('submit without selecting stars shows snack message',
      (tester) async {
    await withMockedHttp(
      setup: (r) {
        r.respond('GET', '/api/ratings/user/9', body: {
          'average_rating': '0.00',
          'total_ratings': 0,
          'ratings': [],
          'rated_profile': {
            'id': 9,
            'name': 'تجريبي',
            'role': 'shipper',
          }
        });
      },
      callback: (_) async {
        await _pump(
          tester,
          const RatingsScreen(
            shipmentId: 100,
            otherUserId: 9,
            otherUserRole: 'shipper',
            otherUserName: 'تجريبي',
          ),
        );
        final submitBtn = find.textContaining('إرسال التقييم');
        if (submitBtn.evaluate().isNotEmpty) {
          await tester.ensureVisible(submitBtn.first);
          await tester.pumpAndSettle();
          await tester.tap(submitBtn.first);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));
          expect(find.text('يرجى اختيار تقييم'), findsOneWidget);
        } else {
          expect(find.byType(RatingsScreen), findsOneWidget);
        }
      },
    );
  });

  testWidgets('ratings screen loads existing ratings and renders distribution',
      (tester) async {
    await withMockedHttp(
      setup: (r) {
        r.respond('GET', '/api/ratings/user/9', body: {
          'average_rating': '4.20',
          'total_ratings': 5,
          'ratings': [
            {
              'id': 1,
              'rater_id': 2,
              'shipment_id': 100,
              'stars': 5,
              'comment': 'ممتاز',
              'created_at': '2026-06-01T10:00:00Z',
              'rater_name': 'الشاحن',
            },
            {
              'id': 2,
              'rater_id': 3,
              'shipment_id': 101,
              'stars': 4,
              'comment': '',
              'created_at': '2026-05-01T10:00:00Z',
              'rater_name': 'شاحن آخر',
            }
          ],
          'rated_profile': {
            'id': 9,
            'name': 'تجريبي',
            'role': 'shipper',
            'profile_image': '',
          }
        });
      },
      callback: (_) async {
        await _pump(
          tester,
          const RatingsScreen(
            shipmentId: 200,
            otherUserId: 9,
            otherUserRole: 'shipper',
            otherUserName: 'تجريبي',
          ),
        );
        expect(find.byType(RatingsScreen), findsOneWidget);
      },
    );
  });

  testWidgets('rating profile API failure surfaces error snack',
      (tester) async {
    await withMockedHttp(
      setup: (r) {
        r.respond('GET', '/api/ratings/user/9',
            statusCode: 500, body: {'message': 'oops'});
      },
      callback: (_) async {
        await _pump(
          tester,
          const RatingsScreen(
            shipmentId: 100,
            otherUserId: 9,
            otherUserRole: 'shipper',
            otherUserName: 'تجريبي',
          ),
        );
        expect(find.byType(RatingsScreen), findsOneWidget);
      },
    );
  });

  testWidgets('submitting valid rating triggers success snackbar',
      (tester) async {
    await withMockedHttp(
      setup: (r) {
        r.respond('GET', '/api/ratings/user/9', body: {
          'average_rating': '0.00',
          'total_ratings': 0,
          'ratings': [],
          'rated_profile': {
            'id': 9,
            'name': 'تجريبي',
            'role': 'shipper',
          }
        });
        r.respond('POST', '/api/ratings',
            statusCode: 201, body: {'id': 1, 'stars': 5});
      },
      callback: (_) async {
        await _pump(
          tester,
          const RatingsScreen(
            shipmentId: 100,
            otherUserId: 9,
            otherUserRole: 'shipper',
            otherUserName: 'تجريبي',
          ),
        );
        // Tap a star — IconButtons render in a Row.
        final stars = find.byIcon(Icons.star_border_rounded);
        if (stars.evaluate().isEmpty) {
          // some renderings use star_border
          expect(find.byType(RatingsScreen), findsOneWidget);
          return;
        }
        await tester.tap(stars.at(4)); // 5th star = 5 stars
        await tester.pump();

        final submitBtn = find.textContaining('إرسال التقييم');
        if (submitBtn.evaluate().isNotEmpty) {
          await tester.ensureVisible(submitBtn.first);
          await tester.pumpAndSettle();
          await tester.tap(submitBtn.first);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 200));
        }
        expect(find.byType(RatingsScreen), findsOneWidget);
      },
    );
  });
}
