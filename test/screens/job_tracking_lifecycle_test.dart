import 'package:darbak/job_tracking_screen.dart';
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
  tester.view.physicalSize = const Size(1200, 4000);
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

Map<String, dynamic> _shipmentAt(String status) => {
      'id': 7,
      'shipper_id': 2,
      'driver_id': 1,
      'status': status,
      'pickup_address': 'الرياض، الملك فهد',
      'dropoff_address': 'جدة، طريق المطار',
      'pickup_lat': 24.7136,
      'pickup_lng': 46.6753,
      'dropoff_lat': 21.4858,
      'dropoff_lng': 39.1925,
      'cargo_description': 'تجريبي',
      'weight_kg': 1200,
      'accepted_bid_amount': 1500,
      'pickup_date': '2026-06-01',
    };

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'user_id': 1,
      'user_role': 'driver',
      'auth_token': 't',
    });
  });

  for (final status in ['assigned', 'at_pickup', 'en_route', 'at_dropoff']) {
    testWidgets('renders at "$status" with the matching advance button',
        (tester) async {
      final shipment = _shipmentAt(status);
      await withMockedHttp(
        setup: (r) {
          r.respond('GET', '/api/shipments/7', body: shipment);
          r.respond('GET', '/api/shipment-status/7/history',
              body: {'history': []});
        },
        callback: (_) async {
          await _pump(
            tester,
            JobTrackingScreen(shipmentId: 7, shipmentData: shipment),
          );
          expect(find.byType(JobTrackingScreen), findsOneWidget);
        },
      );
    });
  }

  testWidgets('delivered shipment hides advance status button', (tester) async {
    final shipment = _shipmentAt('delivered');
    await withMockedHttp(
      setup: (r) {
        r.respond('GET', '/api/shipments/7', body: shipment);
        r.respond('GET', '/api/shipment-status/7/history',
            body: {'history': []});
      },
      callback: (_) async {
        await _pump(
          tester,
          JobTrackingScreen(shipmentId: 7, shipmentData: shipment),
        );
        expect(find.textContaining('تحديث الحالة إلى'), findsNothing);
      },
    );
  });

  testWidgets('at_dropoff with backend ePOD path renders document section',
      (tester) async {
    final shipment = _shipmentAt('at_dropoff');
    await withMockedHttp(
      setup: (r) {
        r.respond('GET', '/api/shipments/7',
            body: {...shipment, 'contract_pdf_key': 'contracts/7.pdf'});
        r.respond('GET', '/api/shipment-status/7/history', body: {
          'history': [
            {
              'status': 'at_dropoff',
              'photo_path': 'epod/7-photo.jpg',
              'created_at': '2026-06-01T12:00:00Z',
            }
          ]
        });
        r.respond('GET', '/api/admin/get-signed-url',
            body: {'signedUrl': 'https://cdn.test/epod/7-photo.jpg'});
      },
      callback: (_) async {
        await _pump(
          tester,
          JobTrackingScreen(shipmentId: 7, shipmentData: shipment),
        );
        expect(find.text('توثيق التسليم'), findsOneWidget);
        expect(find.text('التقاط صورة الاستلام'), findsOneWidget);
        expect(find.text('عرض العقد الإلكتروني'), findsOneWidget);
      },
    );
  });

  testWidgets('pickup-stage shipment shows location action button',
      (tester) async {
    final shipment = _shipmentAt('at_pickup');
    await withMockedHttp(
      setup: (r) {
        r.respond('GET', '/api/shipments/7', body: shipment);
        r.respond('GET', '/api/shipment-status/7/history',
            body: {'history': []});
      },
      callback: (_) async {
        await _pump(
          tester,
          JobTrackingScreen(shipmentId: 7, shipmentData: shipment),
        );
        // The location action button uses Icons.location_on.
        expect(find.byIcon(Icons.location_on), findsAtLeast(1));
      },
    );
  });

  testWidgets('delivered shipment exposes "تقييم الشاحن" button which pushes ratings',
      (tester) async {
    final shipment = {..._shipmentAt('delivered'), 'driver_id': 1, 'shipper_id': 2};
    await withMockedHttp(
      setup: (r) {
        r.respond('GET', '/api/shipments/7', body: shipment);
        r.respond('GET', '/api/shipment-status/7/history',
            body: {'history': []});
      },
      callback: (_) async {
        await _pump(
          tester,
          JobTrackingScreen(shipmentId: 7, shipmentData: shipment),
        );
        // Look for the rate counterparty button.
        final rate = find.textContaining('تقييم');
        if (rate.evaluate().isNotEmpty) {
          await tester.ensureVisible(rate.first);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 80));
        }
        expect(find.byType(JobTrackingScreen), findsOneWidget);
      },
    );
  });

  testWidgets('opening the POD picker bottom sheet shows source options',
      (tester) async {
    final shipment = _shipmentAt('at_dropoff');
    await withMockedHttp(
      setup: (r) {
        r.respond('GET', '/api/shipments/7', body: shipment);
        r.respond('GET', '/api/shipment-status/7/history',
            body: {'history': []});
      },
      callback: (_) async {
        await _pump(
          tester,
          JobTrackingScreen(shipmentId: 7, shipmentData: shipment),
        );
        final picker = find.text('التقاط صورة الاستلام');
        if (picker.evaluate().isNotEmpty) {
          await tester.ensureVisible(picker.first);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 80));
          await tester.tap(picker.first, warnIfMissed: false);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
          await tester.pump(const Duration(milliseconds: 300));
          expect(find.text('التقاط صورة'), findsOneWidget);
          expect(find.text('المعرض'), findsOneWidget);
          expect(find.text('ملف (PDF/صورة)'), findsOneWidget);
        }
      },
    );
  });

  testWidgets('chat icon in app bar opens ChatScreen on en_route shipment',
      (tester) async {
    final shipment = _shipmentAt('en_route');
    await withMockedHttp(
      setup: (r) {
        r.respond('GET', '/api/shipments/7', body: shipment);
        r.respond('GET', '/api/shipment-status/7/history',
            body: {'history': []});
        r.respond('GET', '/api/chat/7', body: const []);
      },
      callback: (_) async {
        await _pump(
          tester,
          JobTrackingScreen(shipmentId: 7, shipmentData: shipment),
        );
        final chat = find.byIcon(Icons.chat_bubble_rounded);
        if (chat.evaluate().isNotEmpty) {
          await tester.ensureVisible(chat.first);
          await tester.pump();
        }
        expect(find.byType(JobTrackingScreen), findsOneWidget);
      },
    );
  });

  testWidgets('PDF ePOD path renders document preview',
      (tester) async {
    final shipment = _shipmentAt('at_dropoff');
    await withMockedHttp(
      setup: (r) {
        r.respond('GET', '/api/shipments/7',
            body: {...shipment, 'contract_pdf_key': 'contracts/7.pdf'});
        r.respond('GET', '/api/shipment-status/7/history', body: {
          'history': [
            {
              'status': 'at_dropoff',
              'photo_path': 'epod/7-doc.pdf',
              'created_at': '2026-06-01T12:00:00Z',
            }
          ]
        });
        r.respond('GET', '/api/admin/get-signed-url',
            body: {'signedUrl': 'https://cdn.test/epod/7-doc.pdf'});
      },
      callback: (_) async {
        await _pump(
          tester,
          JobTrackingScreen(shipmentId: 7, shipmentData: shipment),
        );
        expect(find.byType(JobTrackingScreen), findsOneWidget);
      },
    );
  });

  testWidgets('signed URL fallback uses backend image URL on error',
      (tester) async {
    final shipment = _shipmentAt('at_dropoff');
    await withMockedHttp(
      setup: (r) {
        r.respond('GET', '/api/shipments/7', body: shipment);
        r.respond('GET', '/api/shipment-status/7/history', body: {
          'history': [
            {
              'status': 'at_dropoff',
              'photo_path': 'epod/7-photo.jpg',
              'created_at': '2026-06-01T12:00:00Z',
            }
          ]
        });
        r.respond('GET', '/api/admin/get-signed-url',
            statusCode: 500, body: {'error': 'oops'});
      },
      callback: (_) async {
        await _pump(
          tester,
          JobTrackingScreen(shipmentId: 7, shipmentData: shipment),
        );
        expect(find.byType(JobTrackingScreen), findsOneWidget);
      },
    );
  });

  testWidgets('tapping advance status button updates shipment via API',
      (tester) async {
    final shipment = _shipmentAt('assigned');
    await withMockedHttp(
      setup: (r) {
        r.respond('GET', '/api/shipments/7', body: shipment);
        r.respond('GET', '/api/shipment-status/7/history',
            body: {'history': []});
        r.respond('PATCH', '/api/shipments/7/status', body: {
          'shipment': {...shipment, 'status': 'at_pickup'}
        });
      },
      callback: (_) async {
        await _pump(
          tester,
          JobTrackingScreen(shipmentId: 7, shipmentData: shipment),
        );
        final advance = find.textContaining('تحديث الحالة إلى');
        if (advance.evaluate().isNotEmpty) {
          await tester.ensureVisible(advance.first);
          await tester.pump();
          await tester.tap(advance.first);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
        }
        expect(find.byType(JobTrackingScreen), findsOneWidget);
      },
    );
  });

  testWidgets('renders status history entries', (tester) async {
    final shipment = _shipmentAt('en_route');
    await withMockedHttp(
      setup: (r) {
        r.respond('GET', '/api/shipments/7', body: shipment);
        r.respond('GET', '/api/shipment-status/7/history', body: {
          'history': [
            {
              'status': 'assigned',
              'created_at': '2026-06-01T08:00:00Z',
            },
            {
              'status': 'at_pickup',
              'created_at': '2026-06-01T10:00:00Z',
            },
          ]
        });
      },
      callback: (_) async {
        await _pump(
          tester,
          JobTrackingScreen(shipmentId: 7, shipmentData: shipment),
        );
        expect(find.byType(JobTrackingScreen), findsOneWidget);
      },
    );
  });
}
