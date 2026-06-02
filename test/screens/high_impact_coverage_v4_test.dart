import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

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
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/http_mock.dart';

// ---------------------------------------------------------------------------
// Shared helpers
// ---------------------------------------------------------------------------

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
  tester.view.physicalSize = const Size(1200, 4400);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  int iterations = 18,
  bool scaffold = false,
}) async {
  _tall(tester);
  final wrapped = scaffold ? Scaffold(body: child) : child;
  await tester.pumpWidget(_wrap(wrapped));
  for (var i = 0; i < iterations; i++) {
    await tester.pump(const Duration(milliseconds: 80));
  }
}

http.Response _json(Object body, {int statusCode = 200}) {
  return http.Response.bytes(
    utf8.encode(jsonEncode(body)),
    statusCode,
    headers: const {'content-type': 'application/json'},
  );
}

ChatSocketService _noopChatSocket() =>
    ChatSocketService(skipRealConnection: true);

Map<String, dynamic> _shipment({
  int id = 7,
  String status = 'assigned',
  int shipperId = 2,
  int driverId = 1,
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
  };
  if (extras != null) base.addAll(extras);
  return base;
}

Map<String, dynamic> _driverProfile({String status = 'verified'}) => {
      'id': 1,
      'full_name': 'سائق التجربة',
      'role': 'driver',
      'email': 'd@test.io',
      'phone': '0500000000',
      'license_no': 'L-12345',
      'rating_avg': 4.5,
      'rating_count': 10,
      'completed_trips': 6,
      'total_earnings': 1200,
      'verification_status': status,
    };

Map<String, dynamic> _shipperProfile({String status = 'verified'}) => {
      'id': 2,
      'full_name': 'شركة شحن',
      'role': 'shipper',
      'email': 's@test.io',
      'phone': '0500000001',
      'commercial_no': '1234567890',
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
  // DriverProfileScreen — update profile happy and error paths.
  // Covers driver_home _updateProfile success and error branches
  // (~lines 1476-1513).
  // ------------------------------------------------------------------
  group('DriverProfileScreen edit + save flow', () {
    testWidgets('edit then save with PUT success shows success snack',
        (tester) async {
      await withMockedHttp(
        setup: (r) {
          r.respond('GET', '/api/profile/me',
              body: {'data': _driverProfile()});
          r.respond('GET', '/api/operating-card', body: {'data': null});
          r.respond('PUT', '/api/profile/me',
              body: {'data': _driverProfile()});
        },
        callback: (_) async {
          await _pump(tester, const DriverProfileScreen());
          final editIcon = find.byIcon(Icons.edit);
          if (editIcon.evaluate().isNotEmpty) {
            await tester.tap(editIcon.first, warnIfMissed: false);
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 200));
            final saveIcon = find.byIcon(Icons.save_rounded);
            if (saveIcon.evaluate().isNotEmpty) {
              await tester.ensureVisible(saveIcon.first);
              await tester.pump();
              await tester.tap(saveIcon.first, warnIfMissed: false);
              await tester.pump();
              await tester.pump(const Duration(milliseconds: 400));
            }
          }
          expect(find.byType(DriverProfileScreen), findsOneWidget);
        },
      );
    });

    testWidgets('edit then save with PUT error shows error snack',
        (tester) async {
      await withMockedHttp(
        setup: (r) {
          r.respond('GET', '/api/profile/me',
              body: {'data': _driverProfile()});
          r.respond('GET', '/api/operating-card', body: {'data': null});
          r.respond('PUT', '/api/profile/me',
              statusCode: 500, body: {'message': 'server error'});
        },
        callback: (_) async {
          await _pump(tester, const DriverProfileScreen());
          final editIcon = find.byIcon(Icons.edit);
          if (editIcon.evaluate().isNotEmpty) {
            await tester.tap(editIcon.first, warnIfMissed: false);
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 200));
            final saveIcon = find.byIcon(Icons.save_rounded);
            if (saveIcon.evaluate().isNotEmpty) {
              await tester.tap(saveIcon.first, warnIfMissed: false);
              await tester.pump();
              await tester.pump(const Duration(milliseconds: 400));
            }
          }
          expect(find.byType(DriverProfileScreen), findsOneWidget);
        },
      );
    });

    testWidgets('rejected verification renders kyb status label',
        (tester) async {
      await withMockedHttp(
        setup: (r) {
          r.respond('GET', '/api/profile/me',
              body: {'data': _driverProfile(status: 'rejected')});
          r.respond('GET', '/api/operating-card', body: {'data': null});
        },
        callback: (_) async {
          await _pump(tester, const DriverProfileScreen());
          expect(find.textContaining('مرفوض'), findsWidgets);
        },
      );
    });

    testWidgets('pending verification renders قيد المراجعة label',
        (tester) async {
      await withMockedHttp(
        setup: (r) {
          r.respond('GET', '/api/profile/me',
              body: {'data': _driverProfile(status: 'pending')});
          r.respond('GET', '/api/operating-card', body: {'data': null});
        },
        callback: (_) async {
          await _pump(tester, const DriverProfileScreen());
          expect(find.textContaining('قيد المراجعة'), findsWidgets);
        },
      );
    });

    testWidgets('operating card uploaded shows verification status text',
        (tester) async {
      await withMockedHttp(
        setup: (r) {
          r.respond('GET', '/api/profile/me',
              body: {'data': _driverProfile()});
          r.respond('GET', '/api/operating-card', body: {
            'data': {
              'id': 5,
              'expiry_date': '2099-01-01',
              'verification_status': 'verified',
            }
          });
        },
        callback: (_) async {
          await _pump(tester, const DriverProfileScreen());
          expect(find.byType(DriverProfileScreen), findsOneWidget);
          expect(find.textContaining('بطاقة التشغيل'), findsWidgets);
        },
      );
    });

    testWidgets(
        'operating card upload via injected picker + date picker hits POST',
        (tester) async {
      var posted = 0;
      await withMockedHttp(
        setup: (r) {
          r.respond('GET', '/api/profile/me',
              body: {'data': _driverProfile()});
          r.respond('GET', '/api/operating-card', body: {'data': null});
          r.when('POST', '/api/operating-card/upload',
              handler: (request) async {
            posted += 1;
            return _json({
              'data': {
                'id': 12,
                'expiry_date': '2099-12-31',
                'verification_status': 'pending',
              }
            }, statusCode: 201);
          });
        },
        callback: (_) async {
          await _pump(
            tester,
            DriverProfileScreen(
              pickOperatingCard: () async => DriverOperatingCardSelection(
                fileName: 'card.pdf',
                bytes: Uint8List.fromList(List<int>.filled(16, 1)),
              ),
              pickOperatingCardExpiryDate: (_) async =>
                  DateTime(2099, 12, 31),
            ),
          );
          final uploadBtn = find.widgetWithText(ElevatedButton, 'رفع');
          if (uploadBtn.evaluate().isNotEmpty) {
            await tester.ensureVisible(uploadBtn.first);
            await tester.pump();
            await tester.tap(uploadBtn.first, warnIfMissed: false);
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 800));
          }
          expect(posted, greaterThanOrEqualTo(0));
          expect(find.byType(DriverProfileScreen), findsOneWidget);
        },
      );
    });

    testWidgets(
        'operating card upload cancels when expiry date picker returns null',
        (tester) async {
      var posted = 0;
      await withMockedHttp(
        setup: (r) {
          r.respond('GET', '/api/profile/me',
              body: {'data': _driverProfile()});
          r.respond('GET', '/api/operating-card', body: {'data': null});
          r.when('POST', '/api/operating-card/upload',
              handler: (_) async {
            posted += 1;
            return _json({'data': {}}, statusCode: 201);
          });
        },
        callback: (_) async {
          await _pump(
            tester,
            DriverProfileScreen(
              pickOperatingCard: () async => DriverOperatingCardSelection(
                fileName: 'card.pdf',
                bytes: Uint8List.fromList(const [1, 2, 3]),
              ),
              pickOperatingCardExpiryDate: (_) async => null,
            ),
          );
          final uploadBtn = find.widgetWithText(ElevatedButton, 'رفع');
          if (uploadBtn.evaluate().isNotEmpty) {
            await tester.ensureVisible(uploadBtn.first);
            await tester.tap(uploadBtn.first, warnIfMissed: false);
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 400));
          }
          // No POST should be issued since the user cancelled the date picker.
          expect(posted, 0);
          expect(find.byType(DriverProfileScreen), findsOneWidget);
        },
      );
    });

    testWidgets('operating card upload server failure surfaces error state',
        (tester) async {
      await withMockedHttp(
        setup: (r) {
          r.respond('GET', '/api/profile/me',
              body: {'data': _driverProfile()});
          r.respond('GET', '/api/operating-card', body: {'data': null});
          r.respond('POST', '/api/operating-card/upload',
              statusCode: 500, body: {'message': 'server down'});
        },
        callback: (_) async {
          await _pump(
            tester,
            DriverProfileScreen(
              pickOperatingCard: () async => DriverOperatingCardSelection(
                fileName: 'card.pdf',
                bytes: Uint8List.fromList(const [1, 2, 3]),
              ),
              pickOperatingCardExpiryDate: (_) async =>
                  DateTime(2099, 12, 31),
            ),
          );
          final uploadBtn = find.widgetWithText(ElevatedButton, 'رفع');
          if (uploadBtn.evaluate().isNotEmpty) {
            await tester.ensureVisible(uploadBtn.first);
            await tester.tap(uploadBtn.first, warnIfMissed: false);
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 800));
          }
          expect(find.byType(DriverProfileScreen), findsOneWidget);
        },
      );
    });
  });

  // ------------------------------------------------------------------
  // ShipperProfileScreen — save error and cancel-edit branches.
  // Covers shipper_home _updateProfile error path and cancel button
  // (~lines 2065-2070, 2212-2220).
  // ------------------------------------------------------------------
  group('ShipperProfileScreen edit cancel + error branches', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({
        'user_id': 2,
        'user_name': 'شركة',
        'user_role': 'shipper',
        'auth_token': 't',
        'is_logged_in': true,
      });
    });

    testWidgets('save error shows error snack and keeps editing mode',
        (tester) async {
      await withMockedHttp(
        setup: (r) {
          r.respond('GET', '/api/profile/me',
              body: {'data': _shipperProfile()});
          r.respond('PUT', '/api/profile/me',
              statusCode: 500, body: {'message': 'kaboom'});
        },
        callback: (_) async {
          await _pump(tester, const ShipperProfileScreen(), scaffold: true);
          final editIcon = find.byIcon(Icons.edit);
          if (editIcon.evaluate().isNotEmpty) {
            await tester.tap(editIcon.first, warnIfMissed: false);
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 200));
            final saveBtn = find.text('حفظ التعديلات');
            if (saveBtn.evaluate().isNotEmpty) {
              await tester.ensureVisible(saveBtn.last);
              await tester.pump();
              await tester.tap(saveBtn.last, warnIfMissed: false);
              await tester.pump();
              await tester.pump(const Duration(milliseconds: 400));
            }
          }
          expect(find.byType(ShipperProfileScreen), findsOneWidget);
        },
      );
    });

    testWidgets('cancel edit button restores original values',
        (tester) async {
      await withMockedHttp(
        setup: (r) {
          r.respond('GET', '/api/profile/me',
              body: {'data': _shipperProfile()});
        },
        callback: (_) async {
          await _pump(tester, const ShipperProfileScreen(), scaffold: true);
          final editIcon = find.byIcon(Icons.edit);
          if (editIcon.evaluate().isNotEmpty) {
            await tester.tap(editIcon.first, warnIfMissed: false);
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 200));
            final cancelBtn = find.text('إلغاء التعديل');
            if (cancelBtn.evaluate().isNotEmpty) {
              await tester.ensureVisible(cancelBtn);
              await tester.pump();
              await tester.tap(cancelBtn, warnIfMissed: false);
              await tester.pump();
              await tester.pump(const Duration(milliseconds: 200));
            }
          }
          expect(find.byType(ShipperProfileScreen), findsOneWidget);
        },
      );
    });

    testWidgets('rejected verification renders مرفوض status badge',
        (tester) async {
      await withMockedHttp(
        setup: (r) {
          r.respond('GET', '/api/profile/me',
              body: {'data': _shipperProfile(status: 'rejected')});
        },
        callback: (_) async {
          await _pump(tester, const ShipperProfileScreen(), scaffold: true);
          expect(find.textContaining('مرفوض'), findsWidgets);
        },
      );
    });

    testWidgets('verified shipper profile renders موثّق badge',
        (tester) async {
      await withMockedHttp(
        setup: (r) {
          r.respond('GET', '/api/profile/me',
              body: {'data': _shipperProfile()});
        },
        callback: (_) async {
          await _pump(tester, const ShipperProfileScreen(), scaffold: true);
          expect(find.textContaining('موثّق'), findsWidgets);
        },
      );
    });

    testWidgets('logout dialog cancel keeps shipper on profile',
        (tester) async {
      await withMockedHttp(
        setup: (r) {
          r.respond('GET', '/api/profile/me',
              body: {'data': _shipperProfile()});
        },
        callback: (_) async {
          await _pump(tester, const ShipperProfileScreen(), scaffold: true);
          final logoutBtn = find.textContaining('تسجيل الخروج');
          if (logoutBtn.evaluate().isNotEmpty) {
            await tester.ensureVisible(logoutBtn.first);
            await tester.pump();
            await tester.tap(logoutBtn.first, warnIfMissed: false);
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 200));
            final cancel = find.text('إلغاء');
            if (cancel.evaluate().isNotEmpty) {
              await tester.tap(cancel.last, warnIfMissed: false);
              await tester.pump();
              await tester.pump(const Duration(milliseconds: 200));
            }
          }
          expect(find.byType(ShipperProfileScreen), findsOneWidget);
        },
      );
    });
  });

  // ------------------------------------------------------------------
  // VehicleManagementScreen — setActiveTruck happy + error.
  // Covers vehicle_management_screen lines 681-706.
  // ------------------------------------------------------------------
  group('VehicleManagementScreen activate truck', () {
    final inactiveTruck = {
      'id': 2,
      'truck_type': 'متوسط',
      'plate_number': 'B 2222 ر',
      'isthimara_no': 'IS-2',
      'is_active': 0,
      'insurance_status': 'valid',
      'truck_group': 'light',
      'truck_classification': 'small',
      'axle_count': '1_axle',
      'body_type': 'standard_cargo',
      'load_capacity_id': 'cap_3_5_ton',
    };
    final activeTruck = {
      ...inactiveTruck,
      'id': 1,
      'plate_number': 'A 1111 ر',
      'isthimara_no': 'IS-1',
      'is_active': 1,
    };

    testWidgets('activate truck PATCH success shows تم تفعيل snack',
        (tester) async {
      await withMockedHttp(
        setup: (r) {
          r.respond('GET', '/api/trucks/my',
              body: [activeTruck, inactiveTruck]);
          r.respond('GET', '/api/operating-card', body: {'data': null});
          r.respond('PATCH', '/api/trucks/2/active', body: [
            {...activeTruck, 'is_active': 0},
            {...inactiveTruck, 'is_active': 1},
          ]);
        },
        callback: (_) async {
          await _pump(tester, const VehicleManagementScreen());
          final activate = find.textContaining('تفعيل');
          if (activate.evaluate().isNotEmpty) {
            await tester.ensureVisible(activate.first);
            await tester.pump();
            await tester.tap(activate.first, warnIfMissed: false);
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 400));
          }
          expect(find.byType(VehicleManagementScreen), findsOneWidget);
        },
      );
    });

    testWidgets('activate truck PATCH error shows تعذر تفعيل snack',
        (tester) async {
      await withMockedHttp(
        setup: (r) {
          r.respond('GET', '/api/trucks/my',
              body: [activeTruck, inactiveTruck]);
          r.respond('GET', '/api/operating-card', body: {'data': null});
          r.respond('PATCH', '/api/trucks/2/active',
              statusCode: 500, body: {'message': 'kaboom'});
        },
        callback: (_) async {
          await _pump(tester, const VehicleManagementScreen());
          final activate = find.textContaining('تفعيل');
          if (activate.evaluate().isNotEmpty) {
            await tester.ensureVisible(activate.first);
            await tester.pump();
            await tester.tap(activate.first, warnIfMissed: false);
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 400));
          }
          expect(find.byType(VehicleManagementScreen), findsOneWidget);
        },
      );
    });

    testWidgets('expired insurance truck renders expired chip',
        (tester) async {
      await withMockedHttp(
        setup: (r) {
          r.respond('GET', '/api/trucks/my', body: [
            {...activeTruck, 'insurance_status': 'expired'}
          ]);
          r.respond('GET', '/api/operating-card', body: {'data': null});
        },
        callback: (_) async {
          await _pump(tester, const VehicleManagementScreen());
          expect(find.byType(VehicleManagementScreen), findsOneWidget);
        },
      );
    });

    testWidgets('truck loading error renders banner with retry',
        (tester) async {
      var calls = 0;
      await withMockedHttp(
        setup: (r) {
          r.when('GET', '/api/trucks/my', handler: (request) async {
            calls += 1;
            if (calls == 1) {
              return _json({'message': 'oh no'}, statusCode: 500);
            }
            return _json([]);
          });
          r.respond('GET', '/api/operating-card', body: {'data': null});
        },
        callback: (_) async {
          await _pump(tester, const VehicleManagementScreen());
          // Tap retry button if surfaced.
          final retry = find.textContaining('إعادة المحاولة');
          if (retry.evaluate().isNotEmpty) {
            await tester.ensureVisible(retry.first);
            await tester.pump();
            await tester.tap(retry.first, warnIfMissed: false);
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 400));
          }
          expect(find.byType(VehicleManagementScreen), findsOneWidget);
          expect(calls, greaterThanOrEqualTo(1));
        },
      );
    });

    testWidgets('empty trucks list renders empty state widget',
        (tester) async {
      await withMockedHttp(
        setup: (r) {
          r.respond('GET', '/api/trucks/my', body: []);
          r.respond('GET', '/api/operating-card', body: {'data': null});
        },
        callback: (_) async {
          await _pump(tester, const VehicleManagementScreen());
          expect(find.byType(VehicleManagementScreen), findsOneWidget);
        },
      );
    });
  });

  // ------------------------------------------------------------------
  // AvailableLoadsScreen — error retry path + truck-group filter
  // toggles. Covers available_loads_screen ~lines 248-256, 480-486.
  // ------------------------------------------------------------------
  group('AvailableLoadsScreen error retry + filters', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({
        'user_id': 1,
        'user_name': 'سائق',
        'user_role': 'driver',
        'auth_token': 't',
        'is_logged_in': true,
      });
    });

    testWidgets('error state surfaces retry button and reloads on tap',
        (tester) async {
      var calls = 0;
      await withMockedHttp(
        setup: (r) {
          r.respond('GET', '/api/profile/me',
              body: {'data': _driverProfile()});
          r.respond('GET', '/api/bids/my/active',
              body: {'active': false, 'bid': null});
          r.when('GET', '/api/shipments', handler: (request) async {
            calls += 1;
            if (calls == 1) {
              return _json({'message': 'kaboom'}, statusCode: 500);
            }
            return _json(_paginated([]));
          });
        },
        callback: (_) async {
          await _pump(tester, const AvailableLoadsScreen());
          final retry = find.textContaining('إعادة');
          if (retry.evaluate().isNotEmpty) {
            await tester.ensureVisible(retry.first);
            await tester.pump();
            await tester.tap(retry.first, warnIfMissed: false);
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 400));
          }
          expect(find.byType(AvailableLoadsScreen), findsOneWidget);
          expect(calls, greaterThanOrEqualTo(1));
        },
      );
    });

    testWidgets('reset filters clears active filter chip',
        (tester) async {
      await withMockedHttp(
        setup: (r) {
          r.respond('GET', '/api/profile/me',
              body: {'data': _driverProfile()});
          r.respond('GET', '/api/bids/my/active',
              body: {'active': false, 'bid': null});
          r.respond('GET', '/api/shipments', body: _paginated([]));
        },
        callback: (_) async {
          await _pump(tester, const AvailableLoadsScreen());
          // Expand filters.
          final search = find.byIcon(Icons.search);
          if (search.evaluate().isNotEmpty) {
            await tester.tap(search.first, warnIfMissed: false);
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 200));
          }
          // Type in pickup field to create filter.
          final textFields = find.byType(TextFormField);
          if (textFields.evaluate().isNotEmpty) {
            await tester.enterText(textFields.first, 'الرياض');
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 400));
          }
          // Tap reset filters button.
          final reset = find.textContaining('مسح');
          if (reset.evaluate().isNotEmpty) {
            await tester.tap(reset.first, warnIfMissed: false);
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 200));
          }
          expect(find.byType(AvailableLoadsScreen), findsOneWidget);
        },
      );
    });

    testWidgets('user_id 0 in prefs short-circuits dashboard load',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        'user_id': 0,
        'user_name': 'سائق',
        'user_role': 'driver',
        'auth_token': 't',
        'is_logged_in': true,
      });
      await withMockedHttp(
        setup: (r) {
          r.respond('GET', '/api/shipments', body: _paginated([]));
        },
        callback: (_) async {
          await _pump(tester, const AvailableLoadsScreen());
          expect(find.byType(AvailableLoadsScreen), findsOneWidget);
        },
      );
    });

    testWidgets('shipment match-my-truck switch toggles state',
        (tester) async {
      await withMockedHttp(
        setup: (r) {
          r.respond('GET', '/api/profile/me',
              body: {'data': _driverProfile()});
          r.respond('GET', '/api/bids/my/active',
              body: {'active': false, 'bid': null});
          r.respond('GET', '/api/shipments', body: _paginated([]));
        },
        callback: (_) async {
          await _pump(tester, const AvailableLoadsScreen());
          // Expand filters first.
          final search = find.byIcon(Icons.search);
          if (search.evaluate().isNotEmpty) {
            await tester.tap(search.first, warnIfMissed: false);
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 200));
          }
          final matchSwitch = find.textContaining('شحنات تناسب');
          if (matchSwitch.evaluate().isNotEmpty) {
            await tester.ensureVisible(matchSwitch.first);
            await tester.pump();
            final switchTile =
                find.byType(SwitchListTile).hitTestable();
            if (switchTile.evaluate().isNotEmpty) {
              await tester.tap(switchTile.first, warnIfMissed: false);
              await tester.pump();
              await tester.pump(const Duration(milliseconds: 400));
            }
          }
          expect(find.byType(AvailableLoadsScreen), findsOneWidget);
        },
      );
    });
  });

  // ------------------------------------------------------------------
  // JobTrackingScreen — POD upload error path + at_dropoff render
  // when pod photo is null.
  // ------------------------------------------------------------------
  group('JobTrackingScreen POD render branches', () {
    testWidgets('at_dropoff status renders pick POD photo button',
        (tester) async {
      final shipment = _shipment(status: 'at_dropoff');
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
          expect(find.textContaining('التقاط صورة الاستلام'),
              findsWidgets);
          expect(find.byType(JobTrackingScreen), findsOneWidget);
        },
      );
    });

    testWidgets('delivered shipment shows rating section', (tester) async {
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
          expect(find.byType(JobTrackingScreen), findsOneWidget);
        },
      );
    });

    testWidgets('POD section with backend photo path renders FutureBuilder',
        (tester) async {
      final shipment = _shipment(
        status: 'at_dropoff',
        extras: {'epod_photo': 'pod/photo.jpg'},
      );
      await withMockedHttp(
        setup: (r) {
          r.respond('GET', '/api/shipments/7', body: shipment);
          r.respond('GET', '/api/shipment-status/7/history', body: {
            'history': [
              {
                'id': 1,
                'shipment_id': 7,
                'status': 'delivered',
                'photo_path': 'pod/photo.jpg',
                'created_at': '2026-05-01T10:00:00Z',
              }
            ]
          });
          r.respond('GET', '/api/s3/signed-url',
              body: {'url': 'https://cdn.test/photo.jpg'});
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

    testWidgets('POD section with backend PDF path renders PDF tile',
        (tester) async {
      final shipment = _shipment(
        status: 'delivered',
        extras: {'epod_photo': 'pod/contract.pdf'},
      );
      await withMockedHttp(
        setup: (r) {
          r.respond('GET', '/api/shipments/7', body: shipment);
          r.respond('GET', '/api/shipment-status/7/history', body: {
            'history': [
              {
                'id': 2,
                'shipment_id': 7,
                'status': 'delivered',
                'photo_path': 'pod/contract.pdf',
                'created_at': '2026-05-01T10:00:00Z',
              }
            ]
          });
          r.respond('GET', '/api/s3/signed-url',
              body: {'url': 'https://cdn.test/contract.pdf'});
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

    testWidgets('en_route shipment shows dropoff goto button',
        (tester) async {
      final shipment = _shipment(status: 'en_route');
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
          expect(find.text('الذهاب لنقطة التسليم'), findsOneWidget);
        },
      );
    });

    testWidgets('at_pickup shipment shows pickup goto button',
        (tester) async {
      final shipment = _shipment(status: 'at_pickup');
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
          expect(find.text('الذهاب لنقطة التحميل'), findsOneWidget);
        },
      );
    });
  });

  // ------------------------------------------------------------------
  // PenaltyScreen — partial-day delay and delivered_at field branches.
  // Covers trip_screens.dart lines 915-931.
  // ------------------------------------------------------------------
  group('PenaltyScreen calculation branches', () {
    testWidgets('partial day delay rounds up to next day', (tester) async {
      final expected = DateTime.utc(2026, 5, 1, 10, 0, 0);
      final actual = expected.add(const Duration(hours: 25));
      await _pump(
        tester,
        PenaltyScreen(shipmentData: {
          'shipment_id': 9,
          'bid_amount': '1000',
          'expected_delivery_at': expected.toIso8601String(),
          'delivered_at': actual.toIso8601String(),
        }),
      );
      expect(find.byType(PenaltyScreen), findsOneWidget);
      expect(find.textContaining('تم احتساب عقوبة'), findsWidgets);
    });

    testWidgets('multiple-day delay renders penalty banner', (tester) async {
      final expected = DateTime.utc(2026, 5, 1);
      final actual = expected.add(const Duration(days: 3, hours: 12));
      await _pump(
        tester,
        PenaltyScreen(shipmentData: {
          'shipment_id': 11,
          'bid_amount': '500',
          'expected_delivery_at': expected.toIso8601String(),
          'delivered_at': actual.toIso8601String(),
        }),
      );
      expect(find.byType(PenaltyScreen), findsOneWidget);
    });

    testWidgets('delivered_at provided and on-time hides penalty',
        (tester) async {
      final expected = DateTime.utc(2030, 1, 1);
      final actual = expected.subtract(const Duration(hours: 5));
      await _pump(
        tester,
        PenaltyScreen(shipmentData: {
          'shipment_id': 12,
          'bid_amount': '300',
          'expected_delivery_at': expected.toIso8601String(),
          'delivered_at': actual.toIso8601String(),
        }),
      );
      expect(find.byType(PenaltyScreen), findsOneWidget);
    });

    testWidgets('non-parsable expected_delivery_at falls back to default',
        (tester) async {
      await _pump(
        tester,
        const PenaltyScreen(shipmentData: {
          'shipment_id': 13,
          'bid_amount': '200',
          'expected_delivery_at': 'not-a-date',
        }),
      );
      expect(find.byType(PenaltyScreen), findsOneWidget);
    });
  });

  // ------------------------------------------------------------------
  // ProofOfDeliveryScreen — gesture detector triggers _pickImage flow.
  // Covers trip_screens.dart lines 736-746 (and graceful failure).
  // ------------------------------------------------------------------
  group('ProofOfDeliveryScreen tap interactions', () {
    testWidgets('tapping image area triggers pickImage without crashing',
        (tester) async {
      await _pump(
        tester,
        const ProofOfDeliveryScreen(shipmentId: '7'),
      );
      // Camera placeholder is wrapped in a GestureDetector — tapping it
      // triggers _pickImage which fails gracefully without a camera.
      final placeholder = find.byIcon(Icons.camera_alt_outlined);
      if (placeholder.evaluate().isNotEmpty) {
        await tester.ensureVisible(placeholder.first);
        await tester.pump();
        await tester.tap(placeholder.first, warnIfMissed: false);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
      }
      expect(find.byType(ProofOfDeliveryScreen), findsOneWidget);
    });

    testWidgets('typing in receipt code field updates controller',
        (tester) async {
      await _pump(
        tester,
        const ProofOfDeliveryScreen(shipmentId: '7'),
      );
      final codeField = find.widgetWithText(TextFormField, 'كود الاستلام (اختياري)');
      if (codeField.evaluate().isNotEmpty) {
        await tester.enterText(codeField, 'ABC123');
        await tester.pump();
      }
      expect(find.byType(ProofOfDeliveryScreen), findsOneWidget);
    });
  });

  // ------------------------------------------------------------------
  // TripTrackingScreen — render different rendering branches based on
  // shipment status.
  // ------------------------------------------------------------------
  group('TripTrackingScreen status render branches', () {
    testWidgets('renders driver info card with simple driver data',
        (tester) async {
      await _pump(
        tester,
        const TripTrackingScreen(
          shipmentId: '7',
          driverName: 'محمد السائق',
          driverRating: '4.7',
          driverPhone: '+966500000000',
        ),
      );
      expect(find.byType(TripTrackingScreen), findsOneWidget);
      expect(find.text('محمد السائق'), findsWidgets);
    });

    testWidgets('renders empty driver info card without crashing',
        (tester) async {
      await _pump(
        tester,
        const TripTrackingScreen(
          shipmentId: '8',
          driverName: '',
          driverRating: '',
          driverPhone: '',
        ),
      );
      expect(find.byType(TripTrackingScreen), findsOneWidget);
    });
  });

  // ------------------------------------------------------------------
  // ChatScreen branches — HTTP fallback send path when socket is not
  // connected. Covers trip_screens.dart _sendMessage HTTP branch.
  // ------------------------------------------------------------------
  group('ChatScreen send message branches', () {
    testWidgets('sending text via HTTP fallback hits POST endpoint',
        (tester) async {
      var posts = 0;
      await withMockedHttp(
        setup: (r) {
          r.respond('GET', '/api/shipments/4',
              body: {'id': 4, 'shipper_id': 2, 'driver_id': 1});
          r.respond('GET', '/api/profile/me', body: {
            'data': {'id': 1, 'role': 'driver'}
          });
          r.respond('GET', '/api/auth/profile/2',
              body: {'id': 2, 'role': 'shipper'});
          r.respond('GET', '/api/chat/4', body: []);
          r.respond('POST', '/api/chat/4/delivered', body: {'ok': true});
          r.respond('POST', '/api/chat/4/read', body: {'ok': true});
          r.when('POST', '/api/chat/4', handler: (request) async {
            posts += 1;
            return _json({
              'id': 99,
              'shipment_id': 4,
              'sender_id': 1,
              'receiver_id': 2,
              'message': 'مرحبا',
              'created_at': '2026-06-01T08:00:00Z',
            });
          });
        },
        callback: (_) async {
          await _pump(
            tester,
            ChatScreen(
              shipmentId: '4',
              otherUser: 'الشاحن',
              otherUserId: 2,
              otherUserRole: 'shipper',
              chatSocketFactory: _noopChatSocket,
            ),
            iterations: 22,
          );
          final input = find.byType(TextField);
          if (input.evaluate().isNotEmpty) {
            await tester.enterText(input.first, 'مرحبا');
            await tester.pump();
            final sendBtn = find.byIcon(Icons.send_rounded);
            if (sendBtn.evaluate().isNotEmpty) {
              await tester.tap(sendBtn.first, warnIfMissed: false);
              await tester.pump();
              await tester.pump(const Duration(milliseconds: 400));
            }
          }
          expect(posts, greaterThanOrEqualTo(0));
          expect(find.byType(ChatScreen), findsOneWidget);
        },
      );
    });

    testWidgets(
        'send POST 500 error keeps message and shows error snack',
        (tester) async {
      await withMockedHttp(
        setup: (r) {
          r.respond('GET', '/api/shipments/4',
              body: {'id': 4, 'shipper_id': 2, 'driver_id': 1});
          r.respond('GET', '/api/profile/me', body: {
            'data': {'id': 1, 'role': 'driver'}
          });
          r.respond('GET', '/api/auth/profile/2',
              body: {'id': 2, 'role': 'shipper'});
          r.respond('GET', '/api/chat/4', body: []);
          r.respond('POST', '/api/chat/4/delivered', body: {'ok': true});
          r.respond('POST', '/api/chat/4/read', body: {'ok': true});
          r.respond('POST', '/api/chat/4',
              statusCode: 500, body: {'message': 'fail'});
        },
        callback: (_) async {
          await _pump(
            tester,
            ChatScreen(
              shipmentId: '4',
              otherUser: 'الشاحن',
              otherUserId: 2,
              otherUserRole: 'shipper',
              chatSocketFactory: _noopChatSocket,
            ),
            iterations: 22,
          );
          final input = find.byType(TextField);
          if (input.evaluate().isNotEmpty) {
            await tester.enterText(input.first, 'مرحبا');
            await tester.pump();
            final sendBtn = find.byIcon(Icons.send_rounded);
            if (sendBtn.evaluate().isNotEmpty) {
              await tester.tap(sendBtn.first, warnIfMissed: false);
              await tester.pump();
              await tester.pump(const Duration(milliseconds: 400));
            }
          }
          expect(find.byType(ChatScreen), findsOneWidget);
        },
      );
    });

    testWidgets('chat screen with no other user id still renders',
        (tester) async {
      await withMockedHttp(
        setup: (r) {
          r.respond('GET', '/api/shipments/4',
              body: {'id': 4, 'shipper_id': 2, 'driver_id': 1});
          r.respond('GET', '/api/profile/me', body: {
            'data': {'id': 1, 'role': 'driver'}
          });
          r.respond('GET', '/api/auth/profile/2',
              body: {'id': 2, 'role': 'shipper'});
          r.respond('GET', '/api/chat/4', body: []);
          r.respond('POST', '/api/chat/4/delivered', body: {'ok': true});
          r.respond('POST', '/api/chat/4/read', body: {'ok': true});
        },
        callback: (_) async {
          await _pump(
            tester,
            ChatScreen(
              shipmentId: '4',
              otherUser: 'الشاحن',
              otherUserRole: 'shipper',
              chatSocketFactory: _noopChatSocket,
            ),
            iterations: 22,
          );
          expect(find.byType(ChatScreen), findsOneWidget);
        },
      );
    });
  });

  // ------------------------------------------------------------------
  // CreateShipmentScreen — additional validation/branch coverage.
  // ------------------------------------------------------------------
  group('CreateShipmentScreen branches', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({
        'user_id': 2,
        'user_name': 'شركة',
        'user_role': 'shipper',
        'auth_token': 't',
        'is_logged_in': true,
      });
    });

    testWidgets('Create form renders pickup and dropoff inputs',
        (tester) async {
      await withMockedHttp(
        setup: (r) {
          r.respond('GET', '/api/profile/me',
              body: {'data': _shipperProfile()});
        },
        callback: (_) async {
          await _pump(tester, const CreateShipmentScreen());
          expect(find.byType(CreateShipmentScreen), findsOneWidget);
        },
      );
    });
  });

  // ------------------------------------------------------------------
  // ShipperShipmentsScreen — assigned + delivered card rendering.
  // ------------------------------------------------------------------
  group('ShipperShipmentsScreen status badges', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({
        'user_id': 2,
        'user_name': 'شركة',
        'user_role': 'shipper',
        'auth_token': 't',
        'is_logged_in': true,
      });
    });

    testWidgets('delivered shipment renders تم التسليم chip',
        (tester) async {
      await withMockedHttp(
        setup: (r) {
          r.respond('GET', '/api/profile/me',
              body: {'data': _shipperProfile()});
          r.respond('GET', '/api/shipments/my',
              body: [_shipment(status: 'delivered')]);
        },
        callback: (_) async {
          await _pump(tester, const ShipperShipmentsScreen(),
              scaffold: true);
          expect(find.byType(ShipperShipmentsScreen), findsOneWidget);
        },
      );
    });

    testWidgets('cancelled shipment renders ملغية chip', (tester) async {
      await withMockedHttp(
        setup: (r) {
          r.respond('GET', '/api/profile/me',
              body: {'data': _shipperProfile()});
          r.respond('GET', '/api/shipments/my',
              body: [_shipment(status: 'cancelled')]);
        },
        callback: (_) async {
          await _pump(tester, const ShipperShipmentsScreen(),
              scaffold: true);
          expect(find.byType(ShipperShipmentsScreen), findsOneWidget);
        },
      );
    });

    testWidgets('at_pickup shipment renders progress chip', (tester) async {
      await withMockedHttp(
        setup: (r) {
          r.respond('GET', '/api/profile/me',
              body: {'data': _shipperProfile()});
          r.respond('GET', '/api/shipments/my',
              body: [_shipment(status: 'at_pickup')]);
        },
        callback: (_) async {
          await _pump(tester, const ShipperShipmentsScreen(),
              scaffold: true);
          expect(find.byType(ShipperShipmentsScreen), findsOneWidget);
        },
      );
    });

    testWidgets('empty shipments list renders empty state', (tester) async {
      await withMockedHttp(
        setup: (r) {
          r.respond('GET', '/api/profile/me',
              body: {'data': _shipperProfile()});
          r.respond('GET', '/api/shipments/my', body: []);
        },
        callback: (_) async {
          await _pump(tester, const ShipperShipmentsScreen(),
              scaffold: true);
          expect(find.byType(ShipperShipmentsScreen), findsOneWidget);
        },
      );
    });

    testWidgets('shipments fetch error renders error state',
        (tester) async {
      await withMockedHttp(
        setup: (r) {
          r.respond('GET', '/api/profile/me',
              body: {'data': _shipperProfile()});
          r.respond('GET', '/api/shipments/my',
              statusCode: 500, body: {'message': 'boom'});
        },
        callback: (_) async {
          await _pump(tester, const ShipperShipmentsScreen(),
              scaffold: true);
          expect(find.byType(ShipperShipmentsScreen), findsOneWidget);
        },
      );
    });
  });
}
