import 'package:darbak/shipment_bids_detail_screen.dart';
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

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({'auth_token': 't'});
  });

  testWidgets('accept bid button triggers API and shows success feedback',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 3200);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await withMockedHttp(
      setup: (r) {
        r.respond('GET', '/api/bids/shipment/5', body: [
          {
            'id': 10,
            'shipment_id': 5,
            'driver_id': 9,
            'bid_amount': '900',
            'estimated_days': 4,
            'bid_status': 'pending',
            'driver_name': 'علي',
          }
        ]);
        r.respond('POST', '/api/bids/10/accept', body: {
          'id': 10,
          'contract_pdf_key': 'contracts/5.pdf',
          'contract_id': 1,
        });
      },
      callback: (_) async {
        await tester.pumpWidget(
          _wrap(
            const ShipmentBidsDetailScreen(
              shipmentId: 5,
              pickupAddress: 'الرياض',
              dropoffAddress: 'جدة',
              suggestedPrice: 1500,
            ),
          ),
        );
        for (var i = 0; i < 16; i++) {
          await tester.pump(const Duration(milliseconds: 80));
        }

        // Tap the first accept/outlined action if present.
        final acceptFinder = find.textContaining('قبول');
        if (acceptFinder.evaluate().isNotEmpty) {
          await tester.tap(acceptFinder.first);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 200));
          // Drain the post-accept Navigator.pop timer (5s when contract exists).
          await tester.pump(const Duration(seconds: 6));
        }

        expect(find.textContaining('تم إنشاء عقد'), findsOneWidget);
      },
    );
  });
}
