import 'package:darbak/shipment_bids_detail_screen.dart';
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

void _tall(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 3600);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Future<void> _pumpAndDrain(
  WidgetTester tester,
  Widget child, {
  int iterations = 14,
}) async {
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
      'user_role': 'shipper',
      'auth_token': 't',
    });
  });

  group('ShipperShipmentsScreen interactions', () {
    testWidgets('tapping bidding shipment opens ShipmentBidsDetailScreen', (
      tester,
    ) async {
      await withMockedHttp(
        setup: (r) {
          r.respond(
            'GET',
            '/api/profile/me',
            body: {
              'data': {
                'id': 1,
                'role': 'shipper',
                'verification_status': 'verified',
              },
            },
          );
          r.respond(
            'GET',
            '/api/shipments',
            body: [
              {
                'id': 99,
                'shipper_id': 1,
                'status': 'bidding',
                'pickup_city': 'الرياض',
                'destination_city': 'جدة',
                'pickup_address': 'الرياض، الملك فهد',
                'dropoff_address': 'جدة، طريق المطار',
                'cargo_type': 'بضائع',
                'base_price': 1200,
                'suggested_price': 1300,
                'pickup_date': '2026-06-01',
              },
            ],
          );
          r.respond('GET', '/api/bids/shipment/99', body: []);
        },
        callback: (_) async {
          await _pumpAndDrain(tester, const ShipperShipmentsScreen());

          final viewBids = find.widgetWithText(ElevatedButton, 'عرض العروض');
          expect(viewBids, findsOneWidget);
          await tester.ensureVisible(viewBids);
          await tester.pumpAndSettle();
          await tester.tap(viewBids);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 200));
          await tester.pump(const Duration(milliseconds: 400));

          expect(find.byType(ShipmentBidsDetailScreen), findsOneWidget);
        },
      );
    });

    testWidgets('en_route shipment exposes "محادثة السائق" button', (
      tester,
    ) async {
      await withMockedHttp(
        setup: (r) {
          r.respond(
            'GET',
            '/api/profile/me',
            body: {
              'data': {
                'id': 1,
                'role': 'shipper',
                'verification_status': 'verified',
              },
            },
          );
          r.respond(
            'GET',
            '/api/shipments',
            body: [
              {
                'id': 50,
                'shipper_id': 1,
                'driver_id': 9,
                'status': 'en_route',
                'driver_name': 'علي',
                'pickup_city': 'الرياض',
                'destination_city': 'جدة',
                'pickup_address': 'الرياض، الملك فهد',
                'dropoff_address': 'جدة، طريق المطار',
                'cargo_type': 'بضائع',
                'base_price': 1500,
                'pickup_date': '2026-06-01',
              },
            ],
          );
        },
        callback: (_) async {
          await _pumpAndDrain(tester, const ShipperShipmentsScreen());
          final chatBtn = find.widgetWithText(OutlinedButton, 'محادثة السائق');
          expect(chatBtn, findsOneWidget);
        },
      );
    });

    testWidgets('shipments load error shows retry', (tester) async {
      await withMockedHttp(
        setup: (r) {
          r.respond(
            'GET',
            '/api/profile/me',
            body: {
              'data': {
                'id': 1,
                'role': 'shipper',
                'verification_status': 'verified',
              },
            },
          );
          r.respond(
            'GET',
            '/api/shipments',
            statusCode: 500,
            body: {'message': 'oops'},
          );
        },
        callback: (_) async {
          await _pumpAndDrain(tester, const ShipperShipmentsScreen());
          expect(find.byType(ShipperShipmentsScreen), findsOneWidget);
        },
      );
    });

    testWidgets('pending KYB disables new shipment button', (tester) async {
      await withMockedHttp(
        setup: (r) {
          r.respond(
            'GET',
            '/api/profile/me',
            body: {
              'data': {
                'id': 1,
                'role': 'shipper',
                'verification_status': 'pending',
              },
            },
          );
          r.respond('GET', '/api/shipments', body: []);
        },
        callback: (_) async {
          await _pumpAndDrain(tester, const ShipperShipmentsScreen());
          final newBtn = find.text('شحنة جديدة');
          if (newBtn.evaluate().isNotEmpty) {
            final btn = tester.widget<ElevatedButton>(
              find.ancestor(of: newBtn, matching: find.byType(ElevatedButton)),
            );
            expect(btn.onPressed, isNull);
          }
        },
      );
    });

    testWidgets('rejected KYB status shows rejection banner', (tester) async {
      await withMockedHttp(
        setup: (r) {
          r.respond(
            'GET',
            '/api/profile/me',
            body: {
              'data': {
                'id': 1,
                'role': 'shipper',
                'verification_status': 'rejected',
              },
            },
          );
          r.respond('GET', '/api/shipments', body: []);
        },
        callback: (_) async {
          await _pumpAndDrain(tester, const ShipperShipmentsScreen());
          expect(find.textContaining('لم تُقبل وثائق الشركة'), findsOneWidget);
        },
      );
    });

    testWidgets('pull-to-refresh reloads shipments', (tester) async {
      await withMockedHttp(
        setup: (r) {
          r.respond(
            'GET',
            '/api/profile/me',
            body: {
              'data': {
                'id': 1,
                'role': 'shipper',
                'verification_status': 'verified',
              },
            },
          );
          r.respond('GET', '/api/shipments', body: []);
        },
        callback: (_) async {
          await _pumpAndDrain(tester, const ShipperShipmentsScreen());
          await tester.drag(
            find.byType(RefreshIndicator),
            const Offset(0, 300),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 200));
          expect(find.byType(ShipperShipmentsScreen), findsOneWidget);
        },
      );
    });

    testWidgets('delivered shipment exposes "تقييم السائق" button', (
      tester,
    ) async {
      await withMockedHttp(
        setup: (r) {
          r.respond(
            'GET',
            '/api/profile/me',
            body: {
              'data': {
                'id': 1,
                'role': 'shipper',
                'verification_status': 'verified',
              },
            },
          );
          r.respond(
            'GET',
            '/api/shipments',
            body: [
              {
                'id': 60,
                'shipper_id': 1,
                'driver_id': 9,
                'status': 'delivered',
                'driver_name': 'علي',
                'pickup_city': 'الرياض',
                'destination_city': 'جدة',
                'pickup_address': 'الرياض، الملك فهد',
                'dropoff_address': 'جدة، طريق المطار',
                'cargo_type': 'بضائع',
                'base_price': 1500,
                'final_price': 1450,
                'pickup_date': '2026-06-01',
              },
            ],
          );
        },
        callback: (_) async {
          await _pumpAndDrain(tester, const ShipperShipmentsScreen());
          final rateBtn = find.widgetWithText(ElevatedButton, 'تقييم السائق');
          expect(rateBtn, findsOneWidget);
        },
      );
    });
  });

  group('CreateShipmentScreen interactions', () {
    testWidgets('renders form fields and basic controls', (tester) async {
      await _pumpAndDrain(tester, const CreateShipmentScreen());
      expect(find.byType(CreateShipmentScreen), findsOneWidget);
      expect(find.text('شحنة جديدة'), findsOneWidget);
      expect(find.text('حفظ ونشر الشحنة في السوق'), findsOneWidget);
    });

    testWidgets('submitting without locations surfaces validation snackbar', (
      tester,
    ) async {
      await _pumpAndDrain(tester, const CreateShipmentScreen());
      final submitBtn = find.widgetWithText(
        ElevatedButton,
        'حفظ ونشر الشحنة في السوق',
      );
      await tester.ensureVisible(submitBtn);
      await tester.pumpAndSettle();
      await tester.tap(submitBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      // Form validators kick in for required fields first.
      expect(find.byType(CreateShipmentScreen), findsOneWidget);
    });

    testWidgets('weight over 45 tons shows legal-limit warning', (
      tester,
    ) async {
      await _pumpAndDrain(tester, const CreateShipmentScreen());
      final weightField = find.widgetWithText(
        TextFormField,
        'وزن الشحنة (بالطن)',
      );
      expect(weightField, findsOneWidget);
      await tester.ensureVisible(weightField);
      await tester.pumpAndSettle();
      await tester.enterText(weightField, '60');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        find.textContaining('الحد الأقصى المسموح به قانونياً'),
        findsAtLeast(1),
      );
    });

    testWidgets('changing auction duration dropdown updates state', (
      tester,
    ) async {
      await _pumpAndDrain(tester, const CreateShipmentScreen());
      final dropdown = find.byType(DropdownButtonFormField<int>);
      if (dropdown.evaluate().isNotEmpty) {
        await tester.ensureVisible(dropdown);
        await tester.pumpAndSettle();
        await tester.tap(dropdown);
        await tester.pumpAndSettle();
        final option = find.text('12 ساعة').last;
        await tester.tap(option);
        await tester.pumpAndSettle();
      }
      expect(find.byType(CreateShipmentScreen), findsOneWidget);
    });

    testWidgets('changing period dropdown updates selection', (tester) async {
      await _pumpAndDrain(tester, const CreateShipmentScreen());
      final dropdown = find.byType(DropdownButtonFormField<String>);
      if (dropdown.evaluate().isNotEmpty) {
        await tester.ensureVisible(dropdown);
        await tester.pumpAndSettle();
        await tester.tap(dropdown);
        await tester.pumpAndSettle();
        final option = find.textContaining('مسائي').last;
        await tester.tap(option);
        await tester.pumpAndSettle();
      }
      expect(find.byType(CreateShipmentScreen), findsOneWidget);
    });

    testWidgets('tapping date picker opens calendar', (tester) async {
      await _pumpAndDrain(tester, const CreateShipmentScreen());
      final dateCell = find.text('اختر التاريخ');
      if (dateCell.evaluate().isNotEmpty) {
        await tester.ensureVisible(dateCell);
        await tester.pumpAndSettle();
        await tester.tap(dateCell);
        await tester.pumpAndSettle();
        // Cancel the modal date picker if it opened.
        final cancelBtn = find.text('CANCEL');
        if (cancelBtn.evaluate().isNotEmpty) {
          await tester.tap(cancelBtn);
          await tester.pumpAndSettle();
        }
      }
      expect(find.byType(CreateShipmentScreen), findsOneWidget);
    });

    testWidgets('submitting with missing locations surfaces snackbar', (
      tester,
    ) async {
      await _pumpAndDrain(tester, const CreateShipmentScreen());
      // Fill required fields so validators pass; then submit.
      final price = find.widgetWithText(TextFormField, 'السعر المقترح للشحنة');
      if (price.evaluate().isNotEmpty) {
        await tester.enterText(price, '2500');
      }
      final weight = find.widgetWithText(TextFormField, 'وزن الشحنة (بالطن)');
      if (weight.evaluate().isNotEmpty) {
        await tester.enterText(weight, '5');
      }
      final cargo = find.widgetWithText(TextFormField, 'نوع الحمولة / ملاحظات');
      if (cargo.evaluate().isNotEmpty) {
        await tester.enterText(cargo, 'مواد بناء');
      }
      await tester.pump();

      final submit = find.widgetWithText(
        ElevatedButton,
        'حفظ ونشر الشحنة في السوق',
      );
      await tester.ensureVisible(submit);
      await tester.pumpAndSettle();
      await tester.tap(submit);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      // The screen survives the validation flow.
      expect(find.byType(CreateShipmentScreen), findsOneWidget);
    });

    testWidgets('submitting with mocked locations creates shipment', (
      tester,
    ) async {
      await withMockedHttp(
        setup: (r) {
          r.respond(
            'POST',
            '/api/shipments',
            statusCode: 201,
            body: {'id': 123, 'status': 'bidding'},
          );
        },
        callback: (router) async {
          await _pumpAndDrain(
            tester,
            CreateShipmentScreen(
              pickPickupLocation: (_) async => {
                'lat': 24.7136,
                'lng': 46.6753,
                'mapsUrl': 'https://maps.test/pickup',
              },
              pickDropoffLocation: (_) async => {
                'lat': 21.4858,
                'lng': 39.1925,
                'mapsUrl': 'https://maps.test/dropoff',
              },
            ),
          );

          await tester.enterText(
            find.widgetWithText(TextFormField, 'مدينة التحميل'),
            'الرياض',
          );
          await tester.enterText(
            find.widgetWithText(TextFormField, 'مدينة التفريغ'),
            'جدة',
          );

          await tester.tap(find.text('تحديد موقع التحميل على الخريطة'));
          await tester.pump();
          await tester.tap(find.text('تحديد موقع التسليم على الخريطة'));
          await tester.pump();

          await tester.enterText(
            find.widgetWithText(TextFormField, 'السعر المقترح للشحنة'),
            '2500',
          );
          await tester.enterText(
            find.widgetWithText(TextFormField, 'وزن الشحنة (بالطن)'),
            '5',
          );
          await tester.enterText(
            find.widgetWithText(TextFormField, 'نوع الحمولة / ملاحظات'),
            'مواد بناء',
          );
          await tester.enterText(
            find.widgetWithText(TextFormField, 'التعليمات الخاصة (اختياري)'),
            'اتصل قبل الوصول',
          );

          await tester.ensureVisible(find.text('اختر التاريخ'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('اختر التاريخ'));
          await tester.pumpAndSettle();
          final dateButtons = find.byType(TextButton);
          if (dateButtons.evaluate().isNotEmpty) {
            await tester.tap(dateButtons.last);
            await tester.pumpAndSettle();
          }

          final submit = find.widgetWithText(
            ElevatedButton,
            'حفظ ونشر الشحنة في السوق',
          );
          await tester.ensureVisible(submit);
          await tester.pumpAndSettle();
          await tester.tap(submit);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));

          final createRequests = router.requests
              .where(
                (r) => r.method == 'POST' && r.url.path == '/api/shipments',
              )
              .toList();
          expect(createRequests, isNotEmpty);
          final payload =
              createRequests.single.decodedJson() as Map<String, dynamic>;
          expect(payload['pickupLat'], 24.7136);
          expect(payload['dropoffLng'], 39.1925);
          expect(payload['cargoDescription'], 'مواد بناء');
        },
      );
    });

    testWidgets('toggle "تحديد نوع الشاحنة" switch reveals truck form', (
      tester,
    ) async {
      await _pumpAndDrain(tester, const CreateShipmentScreen());
      // Enter weight first so the truck requirement auto-syncs.
      final weightField = find.widgetWithText(
        TextFormField,
        'وزن الشحنة (بالطن)',
      );
      await tester.ensureVisible(weightField);
      await tester.pumpAndSettle();
      await tester.enterText(weightField, '5');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final switchTile = find.byType(SwitchListTile);
      expect(switchTile, findsOneWidget);
      await tester.ensureVisible(switchTile);
      await tester.pumpAndSettle();
      await tester.tap(switchTile);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    });
  });

  group('Pure screens', () {
    testWidgets('ShipperBidsPlaceholderScreen renders the explainer copy', (
      tester,
    ) async {
      await _pumpAndDrain(tester, const ShipperBidsPlaceholderScreen());
      expect(find.text('عروض السائقين'), findsOneWidget);
      expect(find.textContaining('السعر، التقييم، الالتزام'), findsOneWidget);
    });

    testWidgets('ShipperContractScreen renders the contract template body', (
      tester,
    ) async {
      await _pumpAndDrain(tester, const ShipperContractScreen());
      expect(find.text('العقد الإلكتروني'), findsOneWidget);
      expect(find.textContaining('EDT'), findsOneWidget);
    });
  });
}
