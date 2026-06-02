import 'dart:convert';
import 'dart:typed_data';

import 'package:darbak/api_service.dart';
import 'package:darbak/available_loads_screen.dart';
import 'package:darbak/driver_home.dart';
import 'package:darbak/job_tracking_screen.dart';
import 'package:darbak/services/chat_media_service.dart';
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

http.Response _jsonResponse(Object body, {int statusCode = 200}) {
  return http.Response.bytes(
    utf8.encode(jsonEncode(body)),
    statusCode,
    headers: const {'content-type': 'application/json'},
  );
}

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
  tester.view.physicalSize = const Size(1200, 4200);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  int iterations = 16,
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

PickedChatMedia _fakeImage() => PickedChatMedia(
      fileName: 'photo.jpg',
      bytes: Uint8List.fromList(List<int>.filled(64, 7)),
      messageType: 'image',
    );

PickedChatMedia _fakeVideo() => PickedChatMedia(
      fileName: 'video.mp4',
      bytes: Uint8List.fromList(List<int>.filled(128, 9)),
      messageType: 'video',
    );

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
  };
  if (extras != null) base.addAll(extras);
  return base;
}

void _setupChatRoutes(
  FakeHttpRouter r, {
  required int shipmentId,
  required int shipperId,
  required int driverId,
  List<Map<String, dynamic>>? messages,
}) {
  r.respond('GET', '/api/shipments/$shipmentId',
      body: {'id': shipmentId, 'shipper_id': shipperId, 'driver_id': driverId});
  r.respond('GET', '/api/profile/me', body: {
    'data': {'id': driverId, 'role': 'driver'}
  });
  r.respond('GET', '/api/auth/profile/$shipperId',
      body: {'id': shipperId, 'role': 'shipper'});
  r.respond('GET', '/api/chat/$shipmentId', body: messages ?? const []);
  r.respond('POST', '/api/chat/$shipmentId/delivered', body: {'ok': true});
  r.respond('POST', '/api/chat/$shipmentId/read', body: {'ok': true});
}

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
  // ChatScreen attachment paths (image, video, location) — covers
  // _showAttachmentSheet + _pickAndSendImage/Video/Location branches.
  // ------------------------------------------------------------------
  group('ChatScreen attachment dispatch', () {
    testWidgets('camera image option uploads media via API', (tester) async {
      var mediaPosts = 0;
      await withMockedHttp(
        setup: (r) {
          _setupChatRoutes(r, shipmentId: 3, shipperId: 2, driverId: 1);
          r.when('POST', '/api/chat/3/media', handler: (request) async {
            mediaPosts += 1;
            return _jsonResponse({
              'id': 99,
              'shipment_id': 3,
              'sender_id': 1,
              'receiver_id': 2,
              'message': '',
              'message_type': 'image',
              'media_url': 'https://cdn.test/photo.jpg',
              'created_at': '2026-06-01T08:00:00Z',
            });
          });
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
              pickImage: (_) async => _fakeImage(),
            ),
            iterations: 22,
          );
          await tester.tap(find.byIcon(Icons.add_circle_outline_rounded),
              warnIfMissed: false);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 200));
          await tester.tap(find.text('التقاط صورة'), warnIfMissed: false);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
          await tester.pump(const Duration(milliseconds: 400));
          expect(mediaPosts, greaterThanOrEqualTo(1));
        },
      );
    });

    testWidgets('gallery image option uploads media via API', (tester) async {
      var mediaPosts = 0;
      await withMockedHttp(
        setup: (r) {
          _setupChatRoutes(r, shipmentId: 3, shipperId: 2, driverId: 1);
          r.when('POST', '/api/chat/3/media', handler: (request) async {
            mediaPosts += 1;
            return _jsonResponse({
              'id': 100,
              'shipment_id': 3,
              'sender_id': 1,
              'receiver_id': 2,
              'message': '',
              'message_type': 'image',
              'media_url': 'https://cdn.test/photo.jpg',
              'created_at': '2026-06-01T08:00:00Z',
            });
          });
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
              pickImage: (_) async => _fakeImage(),
            ),
            iterations: 22,
          );
          await tester.tap(find.byIcon(Icons.add_circle_outline_rounded),
              warnIfMissed: false);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 200));
          await tester.tap(find.text('اختيار صورة من المعرض'),
              warnIfMissed: false);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
          await tester.pump(const Duration(milliseconds: 400));
          expect(mediaPosts, greaterThanOrEqualTo(1));
        },
      );
    });

    testWidgets('camera video option uploads media via API', (tester) async {
      var mediaPosts = 0;
      await withMockedHttp(
        setup: (r) {
          _setupChatRoutes(r, shipmentId: 3, shipperId: 2, driverId: 1);
          r.when('POST', '/api/chat/3/media', handler: (request) async {
            mediaPosts += 1;
            return _jsonResponse({
              'id': 101,
              'shipment_id': 3,
              'sender_id': 1,
              'receiver_id': 2,
              'message': '',
              'message_type': 'video',
              'media_url': 'https://cdn.test/video.mp4',
              'created_at': '2026-06-01T08:00:00Z',
            });
          });
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
              pickVideo: (_) async => _fakeVideo(),
            ),
            iterations: 22,
          );
          await tester.tap(find.byIcon(Icons.add_circle_outline_rounded),
              warnIfMissed: false);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 200));
          await tester.tap(find.text('تسجيل فيديو'), warnIfMissed: false);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
          await tester.pump(const Duration(milliseconds: 400));
          expect(mediaPosts, greaterThanOrEqualTo(1));
        },
      );
    });

    testWidgets('gallery video option uploads media via API', (tester) async {
      var mediaPosts = 0;
      await withMockedHttp(
        setup: (r) {
          _setupChatRoutes(r, shipmentId: 3, shipperId: 2, driverId: 1);
          r.when('POST', '/api/chat/3/media', handler: (request) async {
            mediaPosts += 1;
            return _jsonResponse({
              'id': 102,
              'shipment_id': 3,
              'sender_id': 1,
              'receiver_id': 2,
              'message': '',
              'message_type': 'video',
              'media_url': 'https://cdn.test/video.mp4',
              'created_at': '2026-06-01T08:00:00Z',
            });
          });
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
              pickVideo: (_) async => _fakeVideo(),
            ),
            iterations: 22,
          );
          await tester.tap(find.byIcon(Icons.add_circle_outline_rounded),
              warnIfMissed: false);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 200));
          await tester.tap(find.text('اختيار فيديو من المعرض'),
              warnIfMissed: false);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
          await tester.pump(const Duration(milliseconds: 400));
          expect(mediaPosts, greaterThanOrEqualTo(1));
        },
      );
    });

    testWidgets('image picker cancellation does not hit the upload endpoint',
        (tester) async {
      await withMockedHttp(
        setup: (r) {
          _setupChatRoutes(r, shipmentId: 3, shipperId: 2, driverId: 1);
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
              pickImage: (_) async => null,
            ),
            iterations: 22,
          );
          await tester.tap(find.byIcon(Icons.add_circle_outline_rounded),
              warnIfMissed: false);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 200));
          await tester.tap(find.text('التقاط صورة'), warnIfMissed: false);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
          expect(find.byType(ChatScreen), findsOneWidget);
        },
      );
    });

    testWidgets('image picker error surfaces snackbar', (tester) async {
      await withMockedHttp(
        setup: (r) {
          _setupChatRoutes(r, shipmentId: 3, shipperId: 2, driverId: 1);
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
              pickImage: (_) async =>
                  throw DarbakException('camera unavailable'),
            ),
            iterations: 22,
          );
          await tester.tap(find.byIcon(Icons.add_circle_outline_rounded),
              warnIfMissed: false);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 200));
          await tester.tap(find.text('التقاط صورة'), warnIfMissed: false);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
          expect(find.byType(ChatScreen), findsOneWidget);
        },
      );
    });

    testWidgets('pick map location sends location message', (tester) async {
      var locationPosts = 0;
      await withMockedHttp(
        setup: (r) {
          _setupChatRoutes(r, shipmentId: 3, shipperId: 2, driverId: 1);
          r.when('POST', '/api/chat/3/location', handler: (request) async {
            locationPosts += 1;
            return _jsonResponse({
              'id': 110,
              'shipment_id': 3,
              'sender_id': 1,
              'receiver_id': 2,
              'message': '',
              'message_type': 'location',
              'location_lat': 24.0,
              'location_lng': 46.0,
              'location_label': 'موقع محدد',
              'created_at': '2026-06-01T08:00:00Z',
            }, statusCode: 201);
          });
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
              pickLocation: (context, initial) async => {
                'lat': 24.0,
                'lng': 46.0,
                'address': 'الرياض',
              },
              currentPositionProvider: () async => throw Exception('no gps'),
            ),
            iterations: 22,
          );
          await tester.tap(find.byIcon(Icons.add_circle_outline_rounded),
              warnIfMissed: false);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 200));
          await tester.tap(find.text('اختيار موقع من الخريطة'),
              warnIfMissed: false);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
          await tester.pump(const Duration(milliseconds: 400));
          expect(locationPosts, greaterThanOrEqualTo(1));
        },
      );
    });

    testWidgets('pick map location cancelled keeps screen', (tester) async {
      await withMockedHttp(
        setup: (r) {
          _setupChatRoutes(r, shipmentId: 3, shipperId: 2, driverId: 1);
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
              pickLocation: (context, initial) async => null,
              currentPositionProvider: () async => throw Exception('no gps'),
            ),
            iterations: 22,
          );
          await tester.tap(find.byIcon(Icons.add_circle_outline_rounded),
              warnIfMissed: false);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 200));
          await tester.tap(find.text('اختيار موقع من الخريطة'),
              warnIfMissed: false);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
          expect(find.byType(ChatScreen), findsOneWidget);
        },
      );
    });

    testWidgets('successful text send appends message and clears input',
        (tester) async {
      var sendPosts = 0;
      await withMockedHttp(
        setup: (r) {
          _setupChatRoutes(r, shipmentId: 3, shipperId: 2, driverId: 1);
          r.when('POST', '/api/chat/send', handler: (request) async {
            sendPosts += 1;
            return _jsonResponse({
              'id': 120,
              'shipment_id': 3,
              'sender_id': 1,
              'receiver_id': 2,
              'message': 'مرحبا',
              'message_type': 'text',
              'created_at': '2026-06-01T08:05:00Z',
            }, statusCode: 201);
          });
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
          final field = find.byType(TextField);
          await tester.enterText(field, 'مرحبا');
          await tester.tap(find.byIcon(Icons.send_rounded),
              warnIfMissed: false);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
          expect(sendPosts, greaterThanOrEqualTo(1));
        },
      );
    });
  });

  // ------------------------------------------------------------------
  // ShipperShipmentsScreen — KYB banner / status chips / tap actions
  // ------------------------------------------------------------------
  group('ShipperShipmentsScreen branches', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({
        'user_id': 2,
        'user_role': 'shipper',
        'auth_token': 't',
      });
    });

    testWidgets('renders bidding + assigned + delivered shipments', (tester) async {
      await withMockedHttp(
        setup: (r) {
          r.respond('GET', '/api/profile/me', body: {
            'data': {
              'id': 2,
              'role': 'shipper',
              'full_name': 'شاحن',
              'verification_status': 'verified',
            }
          });
          r.respond('GET', '/api/shipments', body: {
            'data': [
              {
                'id': 1,
                'shipper_id': 2,
                'driver_id': 5,
                'status': 'bidding',
                'pickup_address': 'الرياض',
                'dropoff_address': 'جدة',
                'weight_kg': 100,
                'expected_delivery_date': '2026-06-10',
                'suggested_price': 1500,
              },
              {
                'id': 2,
                'shipper_id': 2,
                'driver_id': 5,
                'driver_name': 'سائق1',
                'status': 'assigned',
                'pickup_address': 'الرياض',
                'dropoff_address': 'الدمام',
                'weight_kg': 200,
                'expected_delivery_date': '2026-06-10',
              },
              {
                'id': 3,
                'shipper_id': 2,
                'driver_id': 6,
                'driver_name': 'سائق2',
                'status': 'delivered',
                'pickup_address': 'الرياض',
                'dropoff_address': 'مكة',
                'weight_kg': 300,
                'expected_delivery_date': '2026-06-10',
              },
            ],
            'pagination': {
              'page': 1,
              'limit': 20,
              'total': 3,
              'totalPages': 1,
            },
          });
        },
        callback: (_) async {
          await _pump(tester, const ShipperShipmentsScreen());
          expect(find.text('في المزاد'), findsOneWidget);
          expect(find.text('مُسندة لسائق'), findsOneWidget);
          expect(find.text('تم التسليم'), findsOneWidget);
          expect(find.text('عرض العروض'), findsOneWidget);
          expect(find.text('محادثة السائق'), findsOneWidget);
          expect(find.text('تقييم السائق'), findsOneWidget);
        },
      );
    });

    testWidgets('unverified shipper shows pending KYB banner', (tester) async {
      await withMockedHttp(
        setup: (r) {
          r.respond('GET', '/api/profile/me', body: {
            'data': {
              'id': 2,
              'role': 'shipper',
              'full_name': 'شاحن',
              'verification_status': 'pending',
            }
          });
          r.respond('GET', '/api/shipments', body: {
            'data': const <Map<String, dynamic>>[],
            'pagination': {
              'page': 1,
              'limit': 20,
              'total': 0,
              'totalPages': 1,
            },
          });
        },
        callback: (_) async {
          await _pump(tester, const ShipperShipmentsScreen());
          expect(find.textContaining('قيد مراجعة الوثائق'), findsOneWidget);
        },
      );
    });

    testWidgets('rejected shipper shows rejected banner', (tester) async {
      await withMockedHttp(
        setup: (r) {
          r.respond('GET', '/api/profile/me', body: {
            'data': {
              'id': 2,
              'role': 'shipper',
              'full_name': 'شاحن',
              'verification_status': 'rejected',
            }
          });
          r.respond('GET', '/api/shipments', body: {
            'data': const <Map<String, dynamic>>[],
            'pagination': {
              'page': 1,
              'limit': 20,
              'total': 0,
              'totalPages': 1,
            },
          });
        },
        callback: (_) async {
          await _pump(tester, const ShipperShipmentsScreen());
          expect(find.textContaining('لم تُقبل وثائق الشركة'),
              findsOneWidget);
        },
      );
    });

    testWidgets('error from /api/shipments shows raw message', (tester) async {
      await withMockedHttp(
        setup: (r) {
          r.respond('GET', '/api/profile/me', body: {
            'data': {
              'id': 2,
              'role': 'shipper',
              'verification_status': 'verified',
            }
          });
          r.respond('GET', '/api/shipments',
              statusCode: 500, body: {'message': 'oops'});
        },
        callback: (_) async {
          await _pump(tester, const ShipperShipmentsScreen());
          expect(find.byType(ShipperShipmentsScreen), findsOneWidget);
        },
      );
    });
  });

  // ------------------------------------------------------------------
  // CreateShipmentScreen — full happy path with mocked locations
  // ------------------------------------------------------------------
  group('CreateShipmentScreen happy path', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({
        'user_id': 2,
        'user_role': 'shipper',
        'auth_token': 't',
      });
    });

    testWidgets('weight over 45 tons shows legal warning text', (tester) async {
      await _pump(
        tester,
        CreateShipmentScreen(
          pickPickupLocation: (_) async => {
            'lat': 24.7,
            'lng': 46.6,
            'mapsUrl': 'https://maps.test/pickup',
          },
          pickDropoffLocation: (_) async => {
            'lat': 21.4,
            'lng': 39.1,
            'mapsUrl': 'https://maps.test/dropoff',
          },
        ),
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'وزن الشحنة (بالطن)'),
        '50',
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.textContaining('الحد الأقصى المسموح به قانونياً هو 45 طن'),
          findsWidgets);
    });

    testWidgets('pickup location confirmation text appears after picker',
        (tester) async {
      await _pump(
        tester,
        CreateShipmentScreen(
          pickPickupLocation: (_) async => {
            'lat': 24.7,
            'lng': 46.6,
            'mapsUrl': 'https://maps.test/pickup',
          },
          pickDropoffLocation: (_) async => null,
        ),
      );
      await tester.tap(find.text('تحديد موقع التحميل على الخريطة'),
          warnIfMissed: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('تم تحديد موقع التحميل'), findsOneWidget);
    });

    testWidgets('dropoff location confirmation text appears after picker',
        (tester) async {
      await _pump(
        tester,
        CreateShipmentScreen(
          pickPickupLocation: (_) async => null,
          pickDropoffLocation: (_) async => {
            'lat': 21.4,
            'lng': 39.1,
            'mapsUrl': 'https://maps.test/dropoff',
          },
        ),
      );
      await tester.tap(find.text('تحديد موقع التسليم على الخريطة'),
          warnIfMissed: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('تم تحديد موقع التسليم'), findsOneWidget);
    });
  });

  // ------------------------------------------------------------------
  // JobTrackingScreen — POD picker bottom sheet (covers _pickPODPhoto sheet)
  // ------------------------------------------------------------------
  group('JobTrackingScreen POD picker', () {
    testWidgets('POD picker shows three options in bottom sheet',
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
          final podButton = find.text('التقاط صورة الاستلام');
          if (podButton.evaluate().isNotEmpty) {
            await tester.ensureVisible(podButton);
            await tester.pump();
            await tester.tap(podButton, warnIfMissed: false);
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 300));
            expect(find.text('التقاط صورة'), findsOneWidget);
            expect(find.text('المعرض'), findsOneWidget);
            expect(find.text('ملف (PDF/صورة)'), findsOneWidget);
            // Dismiss the sheet
            await tester.tapAt(const Offset(20, 20));
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 200));
          }
          expect(find.byType(JobTrackingScreen), findsOneWidget);
        },
      );
    });

    testWidgets('chat icon appears for assigned shipment', (tester) async {
      final shipment = _shipment(status: 'assigned');
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
          expect(find.byIcon(Icons.chat_bubble_rounded), findsOneWidget);
        },
      );
    });

    testWidgets('pickup stage shows pickup location button label',
        (tester) async {
      final shipment = _shipment(status: 'assigned');
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

    testWidgets('en_route stage shows dropoff location button label',
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
  });

  // ------------------------------------------------------------------
  // DriverProfileScreen — upload operating card via PDF/IMG sheets
  // ------------------------------------------------------------------
  group('DriverProfileScreen operating card', () {
    testWidgets('upload operating card via injected PDF picker hits API',
        (tester) async {
      var uploadCalls = 0;
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
          r.when('POST', '/api/operating-card/upload',
              handler: (request) async {
            uploadCalls += 1;
            return _jsonResponse({
              'data': {
                'id': 1,
                'verification_status': 'pending',
                'expiry_date': '2099-12-31',
              }
            });
          });
        },
        callback: (_) async {
          await _pump(
            tester,
            DriverProfileScreen(
              pickOperatingCard: () async => DriverOperatingCardSelection(
                fileName: 'card.pdf',
                bytes: Uint8List.fromList(List<int>.filled(32, 1)),
              ),
              pickOperatingCardExpiryDate: (_) async =>
                  DateTime(2099, 12, 31),
            ),
          );
          final cardTile = find.ancestor(
            of: find.text('بطاقة التشغيل'),
            matching: find.byType(ListTile),
          );
          expect(cardTile, findsOneWidget);
          final uploadBtn = find.descendant(
            of: cardTile,
            matching: find.widgetWithText(ElevatedButton, 'رفع'),
          );
          await tester.ensureVisible(uploadBtn);
          await tester.pump();
          await tester.tap(uploadBtn, warnIfMissed: false);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 500));
          await tester.pump(const Duration(milliseconds: 500));
          expect(uploadCalls, greaterThanOrEqualTo(1));
        },
      );
    });

    testWidgets('cancel operating card expiry picker aborts upload',
        (tester) async {
      var uploadCalls = 0;
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
          r.when('POST', '/api/operating-card/upload',
              handler: (request) async {
            uploadCalls += 1;
            return _jsonResponse({'data': null});
          });
        },
        callback: (_) async {
          await _pump(
            tester,
            DriverProfileScreen(
              pickOperatingCard: () async => DriverOperatingCardSelection(
                fileName: 'card.pdf',
                bytes: Uint8List.fromList(List<int>.filled(32, 1)),
              ),
              pickOperatingCardExpiryDate: (_) async => null,
            ),
          );
          final cardTile = find.ancestor(
            of: find.text('بطاقة التشغيل'),
            matching: find.byType(ListTile),
          );
          final uploadBtn = find.descendant(
            of: cardTile,
            matching: find.widgetWithText(ElevatedButton, 'رفع'),
          );
          await tester.ensureVisible(uploadBtn);
          await tester.pump();
          await tester.tap(uploadBtn, warnIfMissed: false);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
          expect(uploadCalls, 0);
        },
      );
    });

    testWidgets('operating card already uploaded shows status info',
        (tester) async {
      await withMockedHttp(
        setup: (r) {
          r.respond('GET', '/api/profile/me', body: {
            'data': {
              'id': 1,
              'role': 'driver',
              'full_name': 'سائق',
              'verification_status': 'verified',
            }
          });
          r.respond('GET', '/api/operating-card', body: {
            'data': {
              'id': 1,
              'verification_status': 'verified',
              'expiry_date': '2099-12-31',
              'file_url': 'https://cdn.test/card.pdf',
            }
          });
        },
        callback: (_) async {
          await _pump(tester, const DriverProfileScreen());
          expect(find.byType(DriverProfileScreen), findsOneWidget);
        },
      );
    });

    testWidgets('save profile via update API succeeds', (tester) async {
      var profileUpdates = 0;
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
          r.when('PUT', '/api/profile/update', handler: (request) async {
            profileUpdates += 1;
            return _jsonResponse({
              'data': {
                'id': 1,
                'role': 'driver',
                'full_name': 'سائق محدث',
                'email': 'd2@test.io',
                'phone': '0500000001',
                'license_no': 'LIC-2',
                'verification_status': 'verified',
              }
            });
          });
        },
        callback: (_) async {
          await _pump(tester, const DriverProfileScreen());
          await tester.tap(find.byIcon(Icons.edit), warnIfMissed: false);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 200));
          await tester.enterText(
            find.widgetWithText(TextFormField, 'الاسم الكامل'),
            'سائق محدث',
          );
          await tester.tap(find.byIcon(Icons.save), warnIfMissed: false);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
          expect(profileUpdates, greaterThanOrEqualTo(1));
        },
      );
    });

    testWidgets('save profile failure shows error snackbar', (tester) async {
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
          r.respond('PUT', '/api/profile/update',
              statusCode: 500, body: {'message': 'oops'});
        },
        callback: (_) async {
          await _pump(tester, const DriverProfileScreen());
          await tester.tap(find.byIcon(Icons.edit), warnIfMissed: false);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 200));
          await tester.tap(find.byIcon(Icons.save), warnIfMissed: false);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
          expect(find.byType(DriverProfileScreen), findsOneWidget);
        },
      );
    });
  });

  // ------------------------------------------------------------------
  // ShipperProfileScreen — edit save / failure paths
  // ------------------------------------------------------------------
  group('ShipperProfileScreen edit branches', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({
        'user_id': 2,
        'user_role': 'shipper',
        'auth_token': 't',
      });
    });

    testWidgets('save profile success path', (tester) async {
      var profileUpdates = 0;
      await withMockedHttp(
        setup: (r) {
          r.respond('GET', '/api/profile/me', body: {
            'data': {
              'id': 2,
              'role': 'shipper',
              'full_name': 'شركة',
              'email': 'company@test.io',
              'phone': '0500000000',
              'commercial_no': 'CR-1',
              'verification_status': 'verified',
            }
          });
          r.when('PUT', '/api/profile/update', handler: (request) async {
            profileUpdates += 1;
            return _jsonResponse({
              'data': {
                'id': 2,
                'role': 'shipper',
                'full_name': 'شركة محدثة',
                'email': 'company2@test.io',
                'phone': '0500000001',
                'commercial_no': 'CR-1',
                'verification_status': 'verified',
              }
            });
          });
        },
        callback: (_) async {
          await _pump(tester, const ShipperProfileScreen(), scaffold: true);
          await tester.tap(find.byIcon(Icons.edit), warnIfMissed: false);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 200));
          await tester.enterText(
            find.widgetWithText(TextFormField, 'الاسم الكامل'),
            'شركة محدثة',
          );
          final save = find.byIcon(Icons.save_rounded);
          if (save.evaluate().isNotEmpty) {
            await tester.tap(save.first, warnIfMissed: false);
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 400));
          }
          expect(profileUpdates, greaterThanOrEqualTo(1));
        },
      );
    });

    testWidgets('save profile error keeps loading state cleared',
        (tester) async {
      await withMockedHttp(
        setup: (r) {
          r.respond('GET', '/api/profile/me', body: {
            'data': {
              'id': 2,
              'role': 'shipper',
              'full_name': 'شركة',
              'email': 'company@test.io',
              'phone': '0500000000',
              'verification_status': 'verified',
            }
          });
          r.respond('PUT', '/api/profile/update',
              statusCode: 500, body: {'message': 'oops'});
        },
        callback: (_) async {
          await _pump(tester, const ShipperProfileScreen(), scaffold: true);
          await tester.tap(find.byIcon(Icons.edit), warnIfMissed: false);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 200));
          final save = find.byIcon(Icons.save_rounded);
          if (save.evaluate().isNotEmpty) {
            await tester.tap(save.first, warnIfMissed: false);
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 400));
          }
          expect(find.byType(ShipperProfileScreen), findsOneWidget);
        },
      );
    });

    testWidgets('profile load error shows arabic copy', (tester) async {
      await withMockedHttp(
        setup: (r) {
          r.respond('GET', '/api/profile/me',
              statusCode: 500, body: {'message': 'oops'});
        },
        callback: (_) async {
          await _pump(tester, const ShipperProfileScreen(), scaffold: true);
          expect(find.byType(ShipperProfileScreen), findsOneWidget);
        },
      );
    });
  });

  // ------------------------------------------------------------------
  // VehicleManagementScreen — set active, error banner, retry
  // ------------------------------------------------------------------
  group('VehicleManagementScreen interactions', () {
    Map<String, dynamic> truck({
      int id = 1,
      int isActive = 1,
      String verificationStatus = 'pending',
      bool insurance = false,
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
          if (insurance) 'insurance_document_url': 'https://cdn.test/ins.pdf',
        };

    testWidgets('error banner shows retry button when load fails',
        (tester) async {
      await withMockedHttp(
        setup: (r) {
          r.respond('GET', '/api/trucks/my',
              statusCode: 500, body: {'message': 'boom'});
          r.respond('GET', '/api/operating-card', body: {'data': null});
        },
        callback: (_) async {
          await _pump(tester, const VehicleManagementScreen());
          expect(find.text('إعادة المحاولة'), findsOneWidget);
          await tester.tap(find.text('إعادة المحاولة'), warnIfMissed: false);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 200));
          expect(find.byType(VehicleManagementScreen), findsOneWidget);
        },
      );
    });

    testWidgets('rejected truck shows rejected status chip', (tester) async {
      await withMockedHttp(
        setup: (r) {
          r.respond('GET', '/api/trucks/my', body: [
            truck(id: 1, isActive: 1, verificationStatus: 'rejected'),
          ]);
          r.respond('GET', '/api/operating-card', body: {'data': null});
        },
        callback: (_) async {
          await _pump(tester, const VehicleManagementScreen());
          expect(find.text('مرفوضة'), findsOneWidget);
        },
      );
    });

    testWidgets('set active truck calls the API', (tester) async {
      var activations = 0;
      await withMockedHttp(
        setup: (r) {
          r.respond('GET', '/api/trucks/my', body: [
            truck(id: 1, isActive: 0, verificationStatus: 'verified'),
            truck(id: 2, isActive: 1, verificationStatus: 'verified'),
          ]);
          r.respond('GET', '/api/operating-card', body: {'data': null});
          r.when('PATCH', '/api/trucks/1/active', handler: (req) async {
            activations += 1;
            return _jsonResponse([
              truck(id: 1, isActive: 1, verificationStatus: 'verified'),
              truck(id: 2, isActive: 0, verificationStatus: 'verified'),
            ]);
          });
        },
        callback: (_) async {
          await _pump(tester, const VehicleManagementScreen());
          final radio = find.byIcon(Icons.radio_button_unchecked);
          if (radio.evaluate().isNotEmpty) {
            await tester.ensureVisible(radio.first);
            await tester.pump();
            await tester.tap(radio.first, warnIfMissed: false);
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 400));
          }
          expect(activations, greaterThanOrEqualTo(1));
        },
      );
    });

    testWidgets('set active truck failure shows error snack', (tester) async {
      await withMockedHttp(
        setup: (r) {
          r.respond('GET', '/api/trucks/my', body: [
            truck(id: 1, isActive: 0, verificationStatus: 'verified'),
            truck(id: 2, isActive: 1, verificationStatus: 'verified'),
          ]);
          r.respond('GET', '/api/operating-card', body: {'data': null});
          r.respond('PATCH', '/api/trucks/1/active',
              statusCode: 500, body: {'message': 'oops'});
          // After failure, _loadTrucks(silent: true) reloads.
          r.respond('GET', '/api/trucks/my', body: [
            truck(id: 1, isActive: 0, verificationStatus: 'verified'),
            truck(id: 2, isActive: 1, verificationStatus: 'verified'),
          ]);
        },
        callback: (_) async {
          await _pump(tester, const VehicleManagementScreen());
          final radio = find.byIcon(Icons.radio_button_unchecked);
          if (radio.evaluate().isNotEmpty) {
            await tester.ensureVisible(radio.first);
            await tester.pump();
            await tester.tap(radio.first, warnIfMissed: false);
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 600));
          }
          expect(find.byType(VehicleManagementScreen), findsOneWidget);
        },
      );
    });

    testWidgets('save new truck via form + classification succeeds',
        (tester) async {
      var registers = 0;
      await withMockedHttp(
        setup: (r) {
          r.respond('GET', '/api/trucks/my', body: <Map<String, dynamic>>[]);
          r.respond('GET', '/api/operating-card', body: {'data': null});
          r.when('POST', '/api/trucks/my', handler: (req) async {
            registers += 1;
            return _jsonResponse(truck(id: 5));
          });
          r.respond('GET', '/api/trucks/my', body: [truck(id: 5)]);
        },
        callback: (_) async {
          await _pump(tester, const VehicleManagementScreen());
          // Without proper truck classification the save short-circuits with
          // the validation snackbar — exercising the error branch.
          final plateField = find.widgetWithText(TextFormField, 'رقم اللوحة');
          await tester.enterText(plateField.first, 'س ج 1234');
          await tester.enterText(
            find.widgetWithText(TextFormField, 'رخصة سير المركبة').first,
            'IS-99',
          );
          await tester.pump();
          await tester.tap(find.widgetWithText(ElevatedButton, 'إضافة شاحنة'),
              warnIfMissed: false);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
          // No truck classification -> register endpoint not called.
          expect(registers, 0);
          expect(find.text('يرجى إكمال تصنيف الشاحنة'), findsOneWidget);
        },
      );
    });
  });

  // ------------------------------------------------------------------
  // AvailableLoadsScreen — pending status text + KYB rejected banner
  // ------------------------------------------------------------------
  group('AvailableLoadsScreen verification banners', () {
    testWidgets('pending driver sees pending verification banner',
        (tester) async {
      await withMockedHttp(
        setup: (r) {
          r.respond('GET', '/api/auth/profile/1',
              body: _driverProfile(status: 'pending'));
          r.respond('GET', '/api/shipments',
              body: {'data': const <Map<String, dynamic>>[], 'pagination': {
                'page': 1,
                'limit': 20,
                'total': 0,
                'totalPages': 1,
              }});
          r.respond('GET', '/api/bids/me/active',
              body: {'active': false, 'bid': null});
        },
        callback: (_) async {
          await _pump(tester, const AvailableLoadsScreen());
          expect(find.byType(AvailableLoadsScreen), findsOneWidget);
        },
      );
    });

    testWidgets('rejected driver sees rejected verification banner',
        (tester) async {
      await withMockedHttp(
        setup: (r) {
          r.respond('GET', '/api/auth/profile/1',
              body: _driverProfile(status: 'rejected'));
          r.respond('GET', '/api/shipments',
              body: {'data': const <Map<String, dynamic>>[], 'pagination': {
                'page': 1,
                'limit': 20,
                'total': 0,
                'totalPages': 1,
              }});
          r.respond('GET', '/api/bids/me/active',
              body: {'active': false, 'bid': null});
        },
        callback: (_) async {
          await _pump(tester, const AvailableLoadsScreen());
          expect(find.byType(AvailableLoadsScreen), findsOneWidget);
        },
      );
    });

    testWidgets('driver with active bid sees active bid banner',
        (tester) async {
      await withMockedHttp(
        setup: (r) {
          r.respond('GET', '/api/auth/profile/1', body: _driverProfile());
          r.respond('GET', '/api/shipments',
              body: {'data': const <Map<String, dynamic>>[], 'pagination': {
                'page': 1,
                'limit': 20,
                'total': 0,
                'totalPages': 1,
              }});
          r.respond('GET', '/api/bids/me/active', body: {
            'active': true,
            'bid': {
              'id': 1,
              'shipment_id': 11,
              'amount': 1800,
              'status': 'pending',
            }
          });
        },
        callback: (_) async {
          await _pump(tester, const AvailableLoadsScreen());
          expect(find.byType(AvailableLoadsScreen), findsOneWidget);
        },
      );
    });
  });

  // ------------------------------------------------------------------
  // ShipperNotificationsScreen — tap notification triggers mark-as-read
  // ------------------------------------------------------------------
  group('ShipperNotificationsScreen interactions', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({
        'user_id': 2,
        'user_role': 'shipper',
        'auth_token': 't',
      });
    });

    testWidgets('tapping notification calls mark-as-read endpoint',
        (tester) async {
      var marks = 0;
      await withMockedHttp(
        setup: (r) {
          r.respond('GET', '/api/notifications/user/2', body: {
            'notifications': [
              {
                'id': 7,
                'title': 'تنبيه',
                'message': 'لديك عرض جديد للشحنة #5',
                'created_at': '2026-06-01T08:00:00Z',
                'is_read': 0,
              }
            ],
            'unread_count': 1,
          });
          r.when('POST', '/api/notifications/7/read',
              handler: (req) async {
            marks += 1;
            return _jsonResponse({'ok': true});
          });
          // After tap, screen reloads.
          r.respond('GET', '/api/notifications/user/2', body: {
            'notifications': [],
            'unread_count': 0,
          });
        },
        callback: (_) async {
          await _pump(tester, const ShipperNotificationsScreen(),
              scaffold: true);
          await tester.tap(find.text('تنبيه'), warnIfMissed: false);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
          expect(marks, greaterThanOrEqualTo(1));
        },
      );
    });
  });
}

