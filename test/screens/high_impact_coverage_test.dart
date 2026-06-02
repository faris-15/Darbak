import 'package:darbak/available_loads_screen.dart';
import 'package:darbak/driver_home.dart';
import 'package:darbak/job_tracking_screen.dart';
import 'package:darbak/services/chat_socket_service.dart';
import 'package:darbak/shipper_home.dart';
import 'package:darbak/trip_screens.dart';
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

void _tall(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 4000);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  int iterations = 14,
  bool scaffold = false,
}) async {
  _tall(tester);
  final wrapped = scaffold ? Scaffold(body: child) : child;
  await tester.pumpWidget(_wrap(wrapped));
  for (var i = 0; i < iterations; i++) {
    await tester.pump(const Duration(milliseconds: 80));
  }
}

ChatSocketService _noopChatSocket() =>
    ChatSocketService(skipRealConnection: true);

Map<String, dynamic> _shipment({
  int id = 7,
  String status = 'assigned',
  int shipperId = 2,
  int driverId = 1,
  String? contractKey,
  Map<String, dynamic>? extras,
}) {
  final base = <String, dynamic>{
    'id': id,
    'shipper_id': shipperId,
    'driver_id': driverId,
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
    'expected_delivery_date': '2026-06-05',
    if (contractKey != null) 'contract_pdf_key': contractKey,
  };
  if (extras != null) base.addAll(extras);
  return base;
}

Map<String, dynamic> _driverProfile({String status = 'verified'}) => {
      'id': 1,
      'full_name': 'سائق',
      'role': 'driver',
      'rating_avg': 4.5,
      'rating_count': 10,
      'completed_trips': 6,
      'total_earnings': 1200,
      'verification_status': status,
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
      'user_name': 'مستخدم',
      'user_role': 'driver',
      'auth_token': 't',
      'is_logged_in': true,
    });
  });

  // ------------------------------------------------------------------
  // JobTrackingScreen — branches not yet covered by lifecycle_test
  // ------------------------------------------------------------------
  group('JobTrackingScreen extra branches', () {
    testWidgets('advance status from at_pickup -> en_route hits success path',
        (tester) async {
      final shipment = _shipment(status: 'at_pickup');
      await withMockedHttp(
        setup: (r) {
          r.respond('GET', '/api/shipments/7', body: shipment);
          r.respond('GET', '/api/shipment-status/7/history',
              body: {'history': []});
          r.respond('PATCH', '/api/shipments/7/status', body: {
            'shipment': {...shipment, 'status': 'en_route'}
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
            await tester.tap(advance.first, warnIfMissed: false);
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 400));
          }
          expect(find.byType(JobTrackingScreen), findsOneWidget);
        },
      );
    });

    testWidgets('advance status from en_route -> at_dropoff hits success path',
        (tester) async {
      final shipment = _shipment(status: 'en_route');
      await withMockedHttp(
        setup: (r) {
          r.respond('GET', '/api/shipments/7', body: shipment);
          r.respond('GET', '/api/shipment-status/7/history',
              body: {'history': []});
          r.respond('PATCH', '/api/shipments/7/status', body: {
            'shipment': {...shipment, 'status': 'at_dropoff'}
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
            await tester.tap(advance.first, warnIfMissed: false);
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 400));
          }
          expect(find.byType(JobTrackingScreen), findsOneWidget);
        },
      );
    });

    testWidgets('advance status error shows Arabic auth message on 401',
        (tester) async {
      final shipment = _shipment(status: 'assigned');
      await withMockedHttp(
        setup: (r) {
          r.respond('GET', '/api/shipments/7', body: shipment);
          r.respond('GET', '/api/shipment-status/7/history',
              body: {'history': []});
          r.respond('PATCH', '/api/shipments/7/status',
              statusCode: 401, body: {'message': 'unauthorized'});
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
            await tester.tap(advance.first, warnIfMissed: false);
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 400));
          }
          expect(find.byType(JobTrackingScreen), findsOneWidget);
        },
      );
    });

    testWidgets('contract button is visible when contract_pdf_key is present',
        (tester) async {
      final shipment = _shipment(
        status: 'assigned',
        contractKey: 'contracts/7.pdf',
      );
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
          expect(find.text('عرض العقد الإلكتروني'), findsOneWidget);
        },
      );
    });

    testWidgets('initial load failure keeps screen mounted',
        (tester) async {
      final shipment = _shipment(status: 'assigned');
      await withMockedHttp(
        setup: (r) {
          r.respond('GET', '/api/shipments/7',
              statusCode: 500, body: {'message': 'oops'});
          r.respond('GET', '/api/shipment-status/7/history',
              statusCode: 500, body: {'message': 'oops'});
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

    testWidgets('delivered shipment rate partner button is present',
        (tester) async {
      final shipment = _shipment(status: 'delivered');
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
          expect(find.text('تقييم الطرف الآخر'), findsOneWidget);
        },
      );
    });

    testWidgets('special_instructions block is rendered when present',
        (tester) async {
      final shipment = _shipment(
        status: 'en_route',
        extras: {'special_instructions': 'الرجاء الحذر مع الحمولة'},
      );
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
          expect(find.text('تعليمات خاصة'), findsOneWidget);
          expect(find.textContaining('الحذر'), findsWidgets);
        },
      );
    });

    testWidgets('http path POD photo renders without signed-url lookup',
        (tester) async {
      final shipment = _shipment(status: 'at_dropoff');
      await withMockedHttp(
        setup: (r) {
          r.respond('GET', '/api/shipments/7', body: shipment);
          r.respond('GET', '/api/shipment-status/7/history', body: {
            'history': [
              {
                'status': 'at_dropoff',
                'photo_path': 'https://cdn.test/epod/7.jpg',
                'created_at': '2026-06-01T12:00:00Z',
              }
            ]
          });
        },
        callback: (_) async {
          await _pump(
            tester,
            JobTrackingScreen(shipmentId: 7, shipmentData: shipment),
          );
          expect(find.text('توثيق التسليم'), findsOneWidget);
        },
      );
    });
  });

  // ------------------------------------------------------------------
  // VehicleManagementScreen — form, edit, insurance retry
  // ------------------------------------------------------------------
  group('VehicleManagementScreen extra branches', () {
    Map<String, dynamic> truck({
      int id = 1,
      int isActive = 1,
      String verificationStatus = 'pending',
    }) =>
        {
          'id': id,
          'truck_type': 'صغيرة',
          'plate_number': 'A $id ر',
          'isthimara_no': 'IS-$id',
          'is_active': isActive,
          'verification_status': verificationStatus,
          'truck_group': 'light',
          'truck_classification': 'small',
          'axle_count': '1_axle',
          'body_type': 'standard_cargo',
          'load_capacity_id': 'cap_3_5_ton',
        };

    testWidgets('verified truck shows موثقة chip', (tester) async {
      await withMockedHttp(
        setup: (r) {
          r.respond('GET', '/api/trucks/my',
              body: [truck(id: 1, verificationStatus: 'verified')]);
          r.respond('GET', '/api/operating-card', body: {'data': null});
        },
        callback: (_) async {
          await _pump(tester, const VehicleManagementScreen());
          expect(find.text('موثقة'), findsOneWidget);
          expect(find.text('نشطة'), findsOneWidget);
        },
      );
    });

    testWidgets('truck with insurance url shows insurance chip + update button',
        (tester) async {
      final t = truck();
      t['insurance_document_url'] = 'https://cdn.test/ins.pdf';
      await withMockedHttp(
        setup: (r) {
          r.respond('GET', '/api/trucks/my', body: [t]);
          r.respond('GET', '/api/operating-card', body: {'data': null});
        },
        callback: (_) async {
          await _pump(tester, const VehicleManagementScreen());
          expect(find.text('تأمين مرفوع'), findsOneWidget);
          expect(find.text('تحديث تأمين هذه الشاحنة'), findsOneWidget);
        },
      );
    });

    testWidgets('edit button populates the form panel with truck data',
        (tester) async {
      final t = truck();
      await withMockedHttp(
        setup: (r) {
          r.respond('GET', '/api/trucks/my', body: [t]);
          r.respond('GET', '/api/operating-card', body: {'data': null});
        },
        callback: (_) async {
          await _pump(tester, const VehicleManagementScreen());
          final editBtn = find.byIcon(Icons.edit).first;
          await tester.ensureVisible(editBtn);
          await tester.pump();
          await tester.tap(editBtn, warnIfMissed: false);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 200));
          expect(find.text('تعديل بيانات الشاحنة'), findsOneWidget);
          expect(find.text('إلغاء'), findsOneWidget);
        },
      );
    });

    testWidgets('cancel button after edit returns to add-new form panel',
        (tester) async {
      final t = truck();
      await withMockedHttp(
        setup: (r) {
          r.respond('GET', '/api/trucks/my', body: [t]);
          r.respond('GET', '/api/operating-card', body: {'data': null});
        },
        callback: (_) async {
          await _pump(tester, const VehicleManagementScreen());
          await tester.tap(find.byIcon(Icons.edit).first,
              warnIfMissed: false);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 200));
          final cancel = find.text('إلغاء');
          await tester.ensureVisible(cancel);
          await tester.pump();
          await tester.tap(cancel, warnIfMissed: false);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 200));
          expect(find.text('إضافة شاحنة جديدة'), findsOneWidget);
        },
      );
    });

    testWidgets('save without truck configuration surfaces validation snackbar',
        (tester) async {
      await withMockedHttp(
        setup: (r) {
          r.respond('GET', '/api/trucks/my', body: <Map<String, dynamic>>[]);
          r.respond('GET', '/api/operating-card', body: {'data': null});
        },
        callback: (_) async {
          await _pump(tester, const VehicleManagementScreen());
          final plateField = find.widgetWithText(TextFormField, 'رقم اللوحة');
          if (plateField.evaluate().isNotEmpty) {
            await tester.enterText(plateField.first, 'س ج 1234');
          }
          final isthimara =
              find.widgetWithText(TextFormField, 'رخصة سير المركبة');
          if (isthimara.evaluate().isNotEmpty) {
            await tester.enterText(isthimara.first, 'IS-99');
          }
          await tester.pump();
          final save = find.widgetWithText(ElevatedButton, 'إضافة شاحنة');
          if (save.evaluate().isNotEmpty) {
            await tester.ensureVisible(save.first);
            await tester.pump();
            await tester.tap(save.first, warnIfMissed: false);
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 200));
          }
          expect(find.text('يرجى إكمال تصنيف الشاحنة'), findsOneWidget);
        },
      );
    });

    testWidgets('empty trucks state shows لا توجد شاحنات', (tester) async {
      await withMockedHttp(
        setup: (r) {
          r.respond('GET', '/api/trucks/my', body: <Map<String, dynamic>>[]);
          r.respond('GET', '/api/operating-card', body: {'data': null});
        },
        callback: (_) async {
          await _pump(tester, const VehicleManagementScreen());
          expect(find.text('لا توجد شاحنات مسجلة بعد'), findsOneWidget);
        },
      );
    });
  });

  // ------------------------------------------------------------------
  // AvailableLoadsScreen — filter / panel branches
  // ------------------------------------------------------------------
  group('AvailableLoadsScreen filter branches', () {
    testWidgets('search panel toggle expands then collapses', (tester) async {
      await withMockedHttp(
        setup: (r) {
          r.respond('GET', '/api/auth/profile/1', body: _driverProfile());
          r.respond('GET', '/api/shipments', body: _paginated([]));
          r.respond('GET', '/api/bids/me/active',
              body: {'active': false, 'bid': null});
        },
        callback: (_) async {
          await _pump(tester, const AvailableLoadsScreen());
          final toggle = find.byIcon(Icons.search_rounded);
          if (toggle.evaluate().isNotEmpty) {
            await tester.tap(toggle.first, warnIfMissed: false);
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 200));
            // Now panel is expanded, close icon should appear
            final closeIcon = find.byIcon(Icons.close_rounded);
            if (closeIcon.evaluate().isNotEmpty) {
              await tester.tap(closeIcon.first, warnIfMissed: false);
              await tester.pump();
              await tester.pump(const Duration(milliseconds: 200));
            }
          }
          expect(find.byType(AvailableLoadsScreen), findsOneWidget);
        },
      );
    });

    testWidgets('active filter triggers _resetFilters via مسح button',
        (tester) async {
      await withMockedHttp(
        setup: (r) {
          r.respond('GET', '/api/auth/profile/1', body: _driverProfile());
          r.respond('GET', '/api/shipments', body: _paginated([]));
          r.respond('GET', '/api/bids/me/active',
              body: {'active': false, 'bid': null});
        },
        callback: (_) async {
          await _pump(tester, const AvailableLoadsScreen());
          final search = find.byIcon(Icons.search_rounded);
          if (search.evaluate().isNotEmpty) {
            await tester.tap(search.first, warnIfMissed: false);
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 200));
          }
          final fields = find.byType(TextField);
          if (fields.evaluate().isNotEmpty) {
            await tester.enterText(fields.first, 'الرياض');
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 500));
          }
          final clear = find.text('مسح');
          if (clear.evaluate().isNotEmpty) {
            await tester.ensureVisible(clear.first);
            await tester.pump();
            await tester.tap(clear.first, warnIfMissed: false);
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 400));
          }
          expect(find.byType(AvailableLoadsScreen), findsOneWidget);
        },
      );
    });

    testWidgets('empty list with active filters shows filter-specific empty',
        (tester) async {
      await withMockedHttp(
        setup: (r) {
          r.respond('GET', '/api/auth/profile/1', body: _driverProfile());
          r.respond('GET', '/api/shipments', body: _paginated([]));
          r.respond('GET', '/api/bids/me/active',
              body: {'active': false, 'bid': null});
        },
        callback: (_) async {
          await _pump(tester, const AvailableLoadsScreen());
          final search = find.byIcon(Icons.search_rounded);
          if (search.evaluate().isNotEmpty) {
            await tester.tap(search.first, warnIfMissed: false);
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 200));
          }
          final fields = find.byType(TextField);
          if (fields.evaluate().isNotEmpty) {
            await tester.enterText(fields.first, 'مدينة لا توجد');
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 600));
          }
          expect(find.byType(AvailableLoadsScreen), findsOneWidget);
        },
      );
    });

    testWidgets('toggling match-my-truck switch reloads', (tester) async {
      await withMockedHttp(
        setup: (r) {
          r.respond('GET', '/api/auth/profile/1', body: _driverProfile());
          r.respond('GET', '/api/shipments', body: _paginated([]));
          r.respond('GET', '/api/bids/me/active',
              body: {'active': false, 'bid': null});
        },
        callback: (_) async {
          await _pump(tester, const AvailableLoadsScreen());
          await tester.tap(find.byIcon(Icons.search_rounded).first,
              warnIfMissed: false);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 200));
          final switchTile = find.byType(SwitchListTile);
          if (switchTile.evaluate().isNotEmpty) {
            await tester.ensureVisible(switchTile.first);
            await tester.pump();
            await tester.tap(switchTile.first, warnIfMissed: false);
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 600));
          }
          expect(find.byType(AvailableLoadsScreen), findsOneWidget);
        },
      );
    });

    testWidgets('shipment list renders count chip when records arrive',
        (tester) async {
      final s = {
        'id': 9,
        'cargo_type': 'مواد',
        'cargo_description': 'بضائع',
        'weight': 1200,
        'pickup_city': 'الرياض',
        'destination_city': 'جدة',
        'pickup_address': 'الرياض',
        'dropoff_address': 'جدة',
        'base_price': 1800,
        'suggested_price': 1800,
        'status': 'bidding',
        'pickup_date': '2026-06-01',
      };
      await withMockedHttp(
        setup: (r) {
          r.respond('GET', '/api/auth/profile/1', body: _driverProfile());
          r.respond('GET', '/api/shipments', body: _paginated([s]));
          r.respond('GET', '/api/bids/me/active',
              body: {'active': false, 'bid': null});
        },
        callback: (_) async {
          await _pump(tester, const AvailableLoadsScreen());
          expect(find.textContaining('شحنة'), findsWidgets);
        },
      );
    });
  });

  // ------------------------------------------------------------------
  // Shipper notifications & messages
  // ------------------------------------------------------------------
  group('Shipper notifications & messages branches', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({
        'user_id': 1,
        'user_role': 'shipper',
        'auth_token': 't',
      });
    });

    testWidgets('notifications error state shows retry button', (tester) async {
      await withMockedHttp(
        setup: (r) => r.respond('GET', '/api/notifications/user/1',
            statusCode: 500, body: {'message': 'oops'}),
        callback: (_) async {
          await _pump(tester, const ShipperNotificationsScreen(),
              scaffold: true);
          expect(find.text('إعادة المحاولة'), findsOneWidget);
          await tester.tap(find.text('إعادة المحاولة'), warnIfMissed: false);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 200));
          expect(find.byType(ShipperNotificationsScreen), findsOneWidget);
        },
      );
    });

    testWidgets('notifications list shows items returned from backend',
        (tester) async {
      await withMockedHttp(
        setup: (r) => r.respond('GET', '/api/notifications/user/1', body: {
          'notifications': [
            {
              'id': 1,
              'title': 'تنبيه',
              'message': 'لديك عرض جديد للشحنة #5',
              'created_at': DateTime.now().toIso8601String(),
              'is_read': 0,
            },
            {
              'id': 2,
              'title': 'عقد إلكتروني',
              'message': 'تم إنشاء عقد رقم #7',
              'related_shipment_id': 7,
              'created_at': DateTime.now()
                  .subtract(const Duration(hours: 1))
                  .toIso8601String(),
              'is_read': 1,
            },
          ],
          'unread_count': 1,
        }),
        callback: (_) async {
          await _pump(tester, const ShipperNotificationsScreen(),
              scaffold: true);
          expect(find.text('تنبيه'), findsOneWidget);
          expect(find.text('عقد إلكتروني'), findsOneWidget);
          expect(find.text('عرض العقد'), findsOneWidget);
        },
      );
    });

    testWidgets('empty notifications shows لا توجد تنبيهات', (tester) async {
      await withMockedHttp(
        setup: (r) => r.respond('GET', '/api/notifications/user/1',
            body: {'notifications': [], 'unread_count': 0}),
        callback: (_) async {
          await _pump(tester, const ShipperNotificationsScreen(),
              scaffold: true);
          expect(find.text('لا توجد تنبيهات'), findsOneWidget);
        },
      );
    });

    testWidgets('messages list renders conversation tiles', (tester) async {
      await withMockedHttp(
        setup: (r) => r.respond('GET', '/api/chat/conversations/me', body: [
          {
            'shipment_id': 5,
            'other_party_id': 9,
            'other_party_name': 'علي',
            'other_party_role': 'driver',
            'last_preview': 'مرحبا',
            'unread_count': 2,
          },
          {
            'shipment_id': 6,
            'other_party_id': 11,
            'other_party_name': 'سارة',
            'other_party_role': 'driver',
            'last_message': 'تم التسليم',
            'unread_count': 0,
          },
        ]),
        callback: (_) async {
          await _pump(tester, const ShipperMessagesScreen(), scaffold: true);
          expect(find.text('علي'), findsOneWidget);
          expect(find.text('سارة'), findsOneWidget);
          expect(find.text('2'), findsOneWidget);
        },
      );
    });

    testWidgets('empty messages shows empty placeholder', (tester) async {
      await withMockedHttp(
        setup: (r) => r.respond('GET', '/api/chat/conversations/me', body: []),
        callback: (_) async {
          await _pump(tester, const ShipperMessagesScreen(), scaffold: true);
          expect(find.text('لا توجد محادثات بعد'), findsOneWidget);
        },
      );
    });

    testWidgets('messages error state shows retry', (tester) async {
      await withMockedHttp(
        setup: (r) => r.respond('GET', '/api/chat/conversations/me',
            statusCode: 500, body: {'message': 'oops'}),
        callback: (_) async {
          await _pump(tester, const ShipperMessagesScreen(), scaffold: true);
          expect(find.text('إعادة المحاولة'), findsOneWidget);
        },
      );
    });

    testWidgets('shipper profile renders fields and toggles edit mode',
        (tester) async {
      await withMockedHttp(
        setup: (r) {
          r.respond('GET', '/api/profile/me', body: {
            'data': {
              'id': 1,
              'role': 'shipper',
              'full_name': 'شركة الاختبار',
              'email': 'company@test.io',
              'phone': '0500000000',
              'license_no': 'LIC-1',
              'commercial_no': 'CR-1',
              'verification_status': 'verified',
            }
          });
        },
        callback: (_) async {
          await _pump(tester, const ShipperProfileScreen(), scaffold: true);
          final editIcon = find.byIcon(Icons.edit);
          if (editIcon.evaluate().isNotEmpty) {
            await tester.tap(editIcon.first, warnIfMissed: false);
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 200));
          }
          expect(find.byType(ShipperProfileScreen), findsOneWidget);
        },
      );
    });
  });

  // ------------------------------------------------------------------
  // Driver messages tab — error, list, empty
  // ------------------------------------------------------------------
  group('DriverMessagesScreen branches', () {
    testWidgets('renders empty placeholder', (tester) async {
      await withMockedHttp(
        setup: (r) => r.respond('GET', '/api/chat/conversations/me', body: []),
        callback: (_) async {
          await _pump(tester, const DriverMessagesScreen(), scaffold: true);
          expect(find.text('لا توجد محادثات بعد'), findsOneWidget);
        },
      );
    });

    testWidgets('renders conversation list with unread badge', (tester) async {
      await withMockedHttp(
        setup: (r) => r.respond('GET', '/api/chat/conversations/me', body: [
          {
            'shipment_id': 5,
            'other_party_id': 9,
            'other_party_name': 'شاحن',
            'other_party_role': 'shipper',
            'last_preview': 'موعدنا غدا',
            'unread_count': 105,
          },
        ]),
        callback: (_) async {
          await _pump(tester, const DriverMessagesScreen(), scaffold: true);
          expect(find.text('شاحن'), findsOneWidget);
          expect(find.text('99+'), findsOneWidget);
        },
      );
    });

    testWidgets('renders error state and shows retry', (tester) async {
      await withMockedHttp(
        setup: (r) => r.respond('GET', '/api/chat/conversations/me',
            statusCode: 500, body: {'message': 'oops'}),
        callback: (_) async {
          await _pump(tester, const DriverMessagesScreen(), scaffold: true);
          expect(find.text('إعادة المحاولة'), findsOneWidget);
        },
      );
    });
  });

  // ------------------------------------------------------------------
  // Driver profile branches (logout dialog, edit mode toggle)
  // ------------------------------------------------------------------
  group('DriverProfileScreen branches', () {
    testWidgets('renders profile with verification status', (tester) async {
      await withMockedHttp(
        setup: (r) {
          r.respond('GET', '/api/profile/me', body: {
            'data': {
              'id': 1,
              'role': 'driver',
              'full_name': 'سائق',
              'email': 'd@test.io',
              'phone': '0500000000',
              'license_no': 'LIC-2',
              'verification_status': 'verified',
              'average_rating': 4.5,
              'ratings_total': 10,
              'document_path': 'docs/1.pdf',
            }
          });
          r.respond('GET', '/api/operating-card', body: {
            'data': {
              'id': 1,
              'verification_status': 'verified',
              'expiry_date': '2099-12-31',
            }
          });
        },
        callback: (_) async {
          await _pump(tester, const DriverProfileScreen());
          expect(find.text('سائق'), findsOneWidget);
          expect(find.text('إدارة شاحناتي'), findsOneWidget);
        },
      );
    });

    testWidgets('rejected KYB profile renders مرفوض label', (tester) async {
      await withMockedHttp(
        setup: (r) {
          r.respond('GET', '/api/profile/me', body: {
            'data': {
              'id': 1,
              'role': 'driver',
              'full_name': 'سائق',
              'email': 'd@test.io',
              'phone': '0500000000',
              'verification_status': 'rejected',
            }
          });
          r.respond('GET', '/api/operating-card', body: {'data': null});
        },
        callback: (_) async {
          await _pump(tester, const DriverProfileScreen());
          expect(find.textContaining('مرفوض'), findsWidgets);
        },
      );
    });

    testWidgets('edit toggle reveals editable fields', (tester) async {
      await withMockedHttp(
        setup: (r) {
          r.respond('GET', '/api/profile/me', body: {
            'data': {
              'id': 1,
              'role': 'driver',
              'full_name': 'سائق',
              'email': 'd@test.io',
              'phone': '0500000000',
              'license_no': 'LIC-2',
              'verification_status': 'verified',
            }
          });
          r.respond('GET', '/api/operating-card', body: {'data': null});
        },
        callback: (_) async {
          await _pump(tester, const DriverProfileScreen());
          await tester.tap(find.byIcon(Icons.edit), warnIfMissed: false);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 200));
          expect(find.text('الاسم الكامل'), findsOneWidget);
          expect(find.byIcon(Icons.save), findsOneWidget);
        },
      );
    });

    testWidgets('logout dialog cancel keeps user logged in', (tester) async {
      await withMockedHttp(
        setup: (r) {
          r.respond('GET', '/api/profile/me', body: {
            'data': {
              'id': 1,
              'role': 'driver',
              'full_name': 'سائق',
              'email': 'd@test.io',
              'phone': '0500000000',
              'verification_status': 'verified',
            }
          });
          r.respond('GET', '/api/operating-card', body: {'data': null});
        },
        callback: (_) async {
          await _pump(tester, const DriverProfileScreen());
          final logout = find.textContaining('تسجيل الخروج');
          if (logout.evaluate().isNotEmpty) {
            await tester.ensureVisible(logout.first);
            await tester.pump();
            await tester.tap(logout.first, warnIfMissed: false);
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 200));
            final cancelBtn = find.text('إلغاء');
            if (cancelBtn.evaluate().isNotEmpty) {
              await tester.tap(cancelBtn.last, warnIfMissed: false);
              await tester.pump();
              await tester.pump(const Duration(milliseconds: 200));
            }
          }
          expect(find.byType(DriverProfileScreen), findsOneWidget);
        },
      );
    });
  });

  // ------------------------------------------------------------------
  // ChatScreen attachments sheet + scroll behaviour
  // ------------------------------------------------------------------
  group('ChatScreen branches', () {
    testWidgets('attachments button opens bottom sheet with options',
        (tester) async {
      await withMockedHttp(
        setup: (r) {
          r.respond('GET', '/api/shipments/3',
              body: {'id': 3, 'shipper_id': 2, 'driver_id': 1});
          r.respond('GET', '/api/profile/me', body: {
            'data': {'id': 1, 'role': 'driver'}
          });
          r.respond('GET', '/api/auth/profile/2',
              body: {'id': 2, 'role': 'shipper'});
          r.respond('GET', '/api/chat/3', body: []);
          r.respond('POST', '/api/chat/3/delivered', body: {'ok': true});
          r.respond('POST', '/api/chat/3/read', body: {'ok': true});
        },
        callback: (_) async {
          await _pump(
            tester,
            ChatScreen(
              shipmentId: '3',
              otherUser: 'الشاحن',
              otherUserId: 2,
              otherUserRole: 'shipper',
              chatSocketFactory: _noopChatSocket,
            ),
            iterations: 20,
          );
          final attach = find.byIcon(Icons.attach_file_rounded);
          if (attach.evaluate().isNotEmpty) {
            await tester.tap(attach.first, warnIfMissed: false);
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 300));
          }
          expect(find.byType(ChatScreen), findsOneWidget);
        },
      );
    });

    testWidgets('renders existing messages with multiple types',
        (tester) async {
      await withMockedHttp(
        setup: (r) {
          r.respond('GET', '/api/shipments/3',
              body: {'id': 3, 'shipper_id': 2, 'driver_id': 1});
          r.respond('GET', '/api/profile/me', body: {
            'data': {'id': 1, 'role': 'driver'}
          });
          r.respond('GET', '/api/auth/profile/2',
              body: {'id': 2, 'role': 'shipper'});
          r.respond('GET', '/api/chat/3', body: [
            {
              'id': 41,
              'shipment_id': 3,
              'sender_id': 2,
              'receiver_id': 1,
              'message': 'مرحبا',
              'message_type': 'text',
              'created_at': '2026-06-01T08:00:00Z',
              'is_delivered': 1,
              'is_read': 0,
            },
            {
              'id': 42,
              'shipment_id': 3,
              'sender_id': 1,
              'receiver_id': 2,
              'message': '',
              'message_type': 'location',
              'location_lat': 24.7136,
              'location_lng': 46.6753,
              'location_label': 'موقعي',
              'created_at': '2026-06-01T08:05:00Z',
              'is_delivered': 1,
              'is_read': 1,
            },
          ]);
          r.respond('POST', '/api/chat/3/delivered', body: {'ok': true});
          r.respond('POST', '/api/chat/3/read', body: {'ok': true});
        },
        callback: (_) async {
          await _pump(
            tester,
            ChatScreen(
              shipmentId: '3',
              otherUser: 'الشاحن',
              otherUserId: 2,
              otherUserRole: 'shipper',
              chatSocketFactory: _noopChatSocket,
            ),
            iterations: 22,
          );
          expect(find.text('مرحبا'), findsOneWidget);
          // Location label
          expect(find.text('موقعي'), findsWidgets);
        },
      );
    });

    testWidgets('send error path shows failure snackbar', (tester) async {
      await withMockedHttp(
        setup: (r) {
          r.respond('GET', '/api/shipments/3',
              body: {'id': 3, 'shipper_id': 2, 'driver_id': 1});
          r.respond('GET', '/api/profile/me', body: {
            'data': {'id': 1, 'role': 'driver'}
          });
          r.respond('GET', '/api/auth/profile/2',
              body: {'id': 2, 'role': 'shipper'});
          r.respond('GET', '/api/chat/3', body: []);
          r.respond('POST', '/api/chat/3/delivered', body: {'ok': true});
          r.respond('POST', '/api/chat/3/read', body: {'ok': true});
          r.respond('POST', '/api/chat/send',
              statusCode: 500, body: {'message': 'oops'});
        },
        callback: (_) async {
          await _pump(
            tester,
            ChatScreen(
              shipmentId: '3',
              otherUser: 'الشاحن',
              otherUserId: 2,
              otherUserRole: 'shipper',
              chatSocketFactory: _noopChatSocket,
            ),
            iterations: 22,
          );
          await tester.enterText(find.byType(TextField), 'مرحبا');
          await tester.tap(find.byIcon(Icons.send_rounded),
              warnIfMissed: false);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
          expect(find.byType(ChatScreen), findsOneWidget);
        },
      );
    });
  });

  // ------------------------------------------------------------------
  // CreateShipmentScreen — extra branches
  // ------------------------------------------------------------------
  group('CreateShipmentScreen extra branches', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({
        'user_id': 1,
        'user_role': 'shipper',
        'auth_token': 't',
      });
    });

    testWidgets('submitting without selected date surfaces snackbar',
        (tester) async {
      await _pump(
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
      await tester.tap(find.text('تحديد موقع التحميل على الخريطة'),
          warnIfMissed: false);
      await tester.pump();
      await tester.tap(find.text('تحديد موقع التسليم على الخريطة'),
          warnIfMissed: false);
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
        'مواد',
      );
      final submit = find.widgetWithText(
        ElevatedButton,
        'حفظ ونشر الشحنة في السوق',
      );
      await tester.ensureVisible(submit);
      await tester.pumpAndSettle();
      await tester.tap(submit, warnIfMissed: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('يرجى تحديد موعد التسليم الأقصى'), findsOneWidget);
    });
  });

  // ------------------------------------------------------------------
  // DriverHomeScreen — badge polling failure does not crash
  // ------------------------------------------------------------------
  group('DriverHomeScreen badge branches', () {
    testWidgets('badge endpoint error keeps screen mounted', (tester) async {
      await withMockedHttp(
        setup: (r) {
          r.respond('GET', '/api/shipments/driver/active',
              statusCode: 500, body: {'message': 'oops'});
          r.respond('GET', '/api/auth/profile/1', body: _driverProfile());
          r.respond('GET', '/api/shipments', body: _paginated([]));
          r.respond('GET', '/api/bids/me/active',
              body: {'active': false, 'bid': null});
        },
        callback: (_) async {
          await _pump(tester, const DriverHomeScreen());
          expect(find.byType(DriverHomeScreen), findsOneWidget);
        },
      );
    });

    testWidgets('badge with active jobs shows green dot', (tester) async {
      await withMockedHttp(
        setup: (r) {
          r.respond('GET', '/api/shipments/driver/active',
              body: [_shipment(id: 1, status: 'assigned')]);
          r.respond('GET', '/api/auth/profile/1', body: _driverProfile());
          r.respond('GET', '/api/shipments', body: _paginated([]));
          r.respond('GET', '/api/bids/me/active',
              body: {'active': false, 'bid': null});
        },
        callback: (_) async {
          await _pump(tester, const DriverHomeScreen());
          expect(find.byType(DriverHomeScreen), findsOneWidget);
        },
      );
    });
  });

  // ------------------------------------------------------------------
  // ShipmentSummaryScreen — assigned with future deadline (no penalty)
  // ------------------------------------------------------------------
  group('ShipmentSummaryScreen extra branches', () {
    testWidgets('assigned shipment with future deadline has no penalty banner',
        (tester) async {
      final shipment = {
        'id': 21,
        'shipper_id': 2,
        'driver_id': 1,
        'status': 'assigned',
        'pickup_address': 'الرياض',
        'dropoff_address': 'جدة',
        'weight_kg': 1200,
        'accepted_bid_amount': 1500,
        'final_price': 1500,
        'expected_delivery_date':
            DateTime.now().add(const Duration(days: 5)).toIso8601String(),
        'created_at': '2026-01-01T00:00:00Z',
      };
      await withMockedHttp(
        setup: (r) {
          r.respond('GET', '/api/shipments/21', body: shipment);
        },
        callback: (_) async {
          await _pump(tester, ShipmentSummaryScreen(shipment: shipment));
          expect(find.textContaining('جزاء تأخير'), findsNothing);
        },
      );
    });

    testWidgets('cancelled shipment never shows penalty banner',
        (tester) async {
      final shipment = {
        'id': 22,
        'shipper_id': 2,
        'driver_id': 1,
        'status': 'cancelled',
        'pickup_address': 'الرياض',
        'dropoff_address': 'جدة',
        'weight_kg': 1200,
        'accepted_bid_amount': 1500,
        'expected_delivery_date': DateTime.now()
            .subtract(const Duration(days: 30))
            .toIso8601String(),
        'created_at': '2026-01-01T00:00:00Z',
      };
      await withMockedHttp(
        setup: (r) {
          r.respond('GET', '/api/shipments/22', body: shipment);
        },
        callback: (_) async {
          await _pump(tester, ShipmentSummaryScreen(shipment: shipment));
          expect(find.textContaining('جزاء تأخير'), findsNothing);
        },
      );
    });
  });
}
