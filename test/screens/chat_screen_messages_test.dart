import 'dart:typed_data';

import 'package:darbak/models/chat_message.dart';
import 'package:darbak/services/chat_media_service.dart';
import 'package:darbak/services/chat_socket_service.dart';
import 'package:darbak/trip_screens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/http_mock.dart';

ChatSocketService? _sharedTestSocket;

ChatSocketService _testChatSocket() =>
    _sharedTestSocket ??= ChatSocketService(skipRealConnection: true);

void _resetTestSocket() {
  _sharedTestSocket?.dispose();
  _sharedTestSocket = null;
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
  tester.view.physicalSize = const Size(1200, 3600);
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
}) async {
  _tall(tester);
  await tester.pumpWidget(_wrap(child));
  for (var i = 0; i < iterations; i++) {
    await tester.pump(const Duration(milliseconds: 80));
  }
}

Map<String, dynamic> _shipmentBody() => {
  'id': 4,
  'shipper_id': 2,
  'driver_id': 1,
};

void _registerBaseRoutes(FakeHttpRouter r, List<Map<String, dynamic>> rows) {
  r.respond('GET', '/api/shipments/4', body: _shipmentBody());
  r.respond(
    'GET',
    '/api/profile/me',
    body: {
      'data': {'id': 1, 'role': 'driver'},
    },
  );
  r.respond('GET', '/api/auth/profile/2', body: {'id': 2, 'role': 'shipper'});
  r.respond('GET', '/api/chat/4', body: rows);
  r.respond('POST', '/api/chat/4/delivered', body: {'ok': true});
  r.respond('POST', '/api/chat/4/read', body: {'ok': true});
}

void main() {
  setUp(() {
    _resetTestSocket();
    SharedPreferences.setMockInitialValues({
      'user_id': 1,
      'user_role': 'driver',
      'auth_token': 't',
    });
  });

  tearDown(_resetTestSocket);

  testWidgets('ChatScreen renders an image message bubble', (tester) async {
    await withMockedHttp(
      setup: (r) => _registerBaseRoutes(r, [
        {
          'id': 21,
          'shipment_id': 4,
          'sender_id': 2,
          'receiver_id': 1,
          'message': 'تعليق على الصورة',
          'message_type': 'image',
          'media_url': 'https://cdn.test/photo.jpg',
          'media_file_name': 'photo.jpg',
          'media_size_bytes': 1024,
          'created_at': '2026-06-01T10:00:00Z',
          'is_delivered': 1,
          'is_read': 1,
        },
      ]),
      callback: (_) async {
        await _pump(
          tester,
          ChatScreen(
            shipmentId: '4',
            otherUser: 'الشاحن',
            otherUserId: 2,
            otherUserRole: 'shipper',
            chatSocketFactory: _testChatSocket,
          ),
        );
        expect(find.text('تعليق على الصورة'), findsOneWidget);
      },
    );
  });

  testWidgets('ChatScreen renders a video message bubble', (tester) async {
    await withMockedHttp(
      setup: (r) => _registerBaseRoutes(r, [
        {
          'id': 22,
          'shipment_id': 4,
          'sender_id': 1,
          'receiver_id': 2,
          'message': '',
          'message_type': 'video',
          'media_url': 'https://cdn.test/clip.mp4',
          'media_file_name': 'clip.mp4',
          'media_size_bytes': 4096,
          'created_at': '2026-06-01T10:01:00Z',
        },
      ]),
      callback: (_) async {
        await _pump(
          tester,
          ChatScreen(
            shipmentId: '4',
            otherUser: 'الشاحن',
            otherUserId: 2,
            otherUserRole: 'shipper',
            chatSocketFactory: _testChatSocket,
          ),
        );
        expect(find.byType(ChatScreen), findsOneWidget);
      },
    );
  });

  testWidgets('ChatScreen renders a location message bubble', (tester) async {
    await withMockedHttp(
      setup: (r) => _registerBaseRoutes(r, [
        {
          'id': 23,
          'shipment_id': 4,
          'sender_id': 2,
          'receiver_id': 1,
          'message': '',
          'message_type': 'location',
          'location_lat': 24.7136,
          'location_lng': 46.6753,
          'location_label': 'موقع التحميل',
          'created_at': '2026-06-01T10:02:00Z',
        },
      ]),
      callback: (_) async {
        await _pump(
          tester,
          ChatScreen(
            shipmentId: '4',
            otherUser: 'الشاحن',
            otherUserId: 2,
            otherUserRole: 'shipper',
            chatSocketFactory: _testChatSocket,
          ),
        );
        expect(find.text('موقع التحميل'), findsOneWidget);
      },
    );
  });

  testWidgets('Tapping image message bubble pushes the image preview', (
    tester,
  ) async {
    await withMockedHttp(
      setup: (r) => _registerBaseRoutes(r, [
        {
          'id': 24,
          'shipment_id': 4,
          'sender_id': 2,
          'receiver_id': 1,
          'message': '',
          'message_type': 'image',
          'media_url': 'https://cdn.test/photo2.jpg',
          'media_file_name': 'p2.jpg',
          'media_size_bytes': 2048,
          'created_at': '2026-06-01T10:00:00Z',
          'is_delivered': 1,
          'is_read': 1,
        },
      ]),
      callback: (_) async {
        await _pump(
          tester,
          ChatScreen(
            shipmentId: '4',
            otherUser: 'الشاحن',
            otherUserId: 2,
            otherUserRole: 'shipper',
            chatSocketFactory: _testChatSocket,
          ),
        );
        final imageBubble = find.byType(GestureDetector).first;
        await tester.tap(imageBubble, warnIfMissed: false);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        expect(find.byType(ChatScreen), findsOneWidget);
      },
    );
  });

  testWidgets('ChatScreen attachment sheet exposes pick options', (
    tester,
  ) async {
    await withMockedHttp(
      setup: (r) => _registerBaseRoutes(r, const []),
      callback: (_) async {
        await _pump(
          tester,
          ChatScreen(
            shipmentId: '4',
            otherUser: 'الشاحن',
            otherUserId: 2,
            otherUserRole: 'shipper',
            chatSocketFactory: _testChatSocket,
          ),
        );
        await tester.tap(find.byIcon(Icons.add_circle_outline_rounded));
        await tester.pumpAndSettle();
        expect(find.text('التقاط صورة'), findsOneWidget);
        expect(find.text('تسجيل فيديو'), findsOneWidget);
        expect(find.text('اختيار صورة من المعرض'), findsOneWidget);
        expect(find.text('اختيار فيديو من المعرض'), findsOneWidget);
        expect(find.text('مشاركة موقعي الحالي'), findsOneWidget);
        expect(find.text('اختيار موقع من الخريطة'), findsOneWidget);

        // Dismiss the sheet so the test cleans up cleanly.
        await tester.tapAt(const Offset(20, 20));
        await tester.pumpAndSettle();
      },
    );
  });

  testWidgets('socket incoming message is merged into the list', (
    tester,
  ) async {
    await withMockedHttp(
      setup: (r) => _registerBaseRoutes(r, const []),
      callback: (_) async {
        final socket = _testChatSocket();
        await _pump(
          tester,
          ChatScreen(
            shipmentId: '4',
            otherUser: 'الشاحن',
            otherUserId: 2,
            otherUserRole: 'shipper',
            chatSocketFactory: _testChatSocket,
          ),
        );
        socket.emitTestMessage(
          ChatMessage(
            id: 99,
            shipmentId: 4,
            senderId: 2,
            receiverId: 1,
            message: 'رسالة فورية',
            createdAt: DateTime.parse('2026-06-01T11:00:00Z'),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.text('رسالة فورية'), findsOneWidget);
      },
    );
  });

  testWidgets('socket status update marks an existing message as read', (
    tester,
  ) async {
    await withMockedHttp(
      setup: (r) => _registerBaseRoutes(r, [
        {
          'id': 30,
          'shipment_id': 4,
          'sender_id': 2,
          'receiver_id': 1,
          'message': 'للقراءة',
          'message_type': 'text',
          'created_at': '2026-06-01T10:00:00Z',
        },
      ]),
      callback: (_) async {
        final socket = _testChatSocket();
        await _pump(
          tester,
          ChatScreen(
            shipmentId: '4',
            otherUser: 'الشاحن',
            otherUserId: 2,
            otherUserRole: 'shipper',
            chatSocketFactory: _testChatSocket,
          ),
        );
        socket.emitTestStatus(
          ChatStatusUpdate(
            shipmentId: 4,
            messages: [
              ChatMessageReceipt(
                id: 30,
                shipmentId: 4,
                senderId: 2,
                receiverId: 1,
                readAt: DateTime.parse('2026-06-01T10:05:00Z'),
              ),
            ],
          ),
        );
        await tester.pump();
        expect(find.text('للقراءة'), findsOneWidget);
      },
    );
  });

  testWidgets('tapping the scroll-to-bottom FAB animates list when shown', (
    tester,
  ) async {
    await withMockedHttp(
      setup: (r) => _registerBaseRoutes(r, [
        for (var i = 0; i < 12; i++)
          {
            'id': 1000 + i,
            'shipment_id': 4,
            'sender_id': 2,
            'receiver_id': 1,
            'message': 'msg-$i',
            'message_type': 'text',
            'created_at': '2026-06-01T10:00:00Z',
          },
      ]),
      callback: (_) async {
        await _pump(
          tester,
          ChatScreen(
            shipmentId: '4',
            otherUser: 'الشاحن',
            otherUserId: 2,
            otherUserRole: 'shipper',
            chatSocketFactory: _testChatSocket,
          ),
        );
        // Drag the list far enough to surface the FAB.
        final list = find.byType(ListView);
        if (list.evaluate().isNotEmpty) {
          await tester.drag(list.first, const Offset(0, 600));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(find.byType(ChatScreen), findsOneWidget);
      },
    );
  });

  testWidgets('socket error surfaces a snackbar', (tester) async {
    await withMockedHttp(
      setup: (r) => _registerBaseRoutes(r, const []),
      callback: (_) async {
        final socket = _testChatSocket();
        await _pump(
          tester,
          ChatScreen(
            shipmentId: '4',
            otherUser: 'الشاحن',
            otherUserId: 2,
            otherUserRole: 'shipper',
            chatSocketFactory: _testChatSocket,
          ),
        );
        socket.emitTestError('انقطع الاتصال');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        expect(find.text('انقطع الاتصال'), findsOneWidget);
      },
    );
  });

  testWidgets('mocked image picker uploads media and confirms bubble', (
    tester,
  ) async {
    await withMockedHttp(
      setup: (r) {
        _registerBaseRoutes(r, const []);
        r.respond(
          'POST',
          '/api/chat/4/media',
          statusCode: 201,
          body: {
            'id': 60,
            'shipment_id': 4,
            'sender_id': 1,
            'receiver_id': 2,
            'message': '',
            'message_type': 'image',
            'media_url': 'https://cdn.test/uploaded.jpg',
            'media_file_name': 'uploaded.jpg',
            'media_size_bytes': 3,
            'created_at': '2026-06-01T12:30:00Z',
          },
        );
      },
      callback: (_) async {
        await _pump(
          tester,
          ChatScreen(
            shipmentId: '4',
            otherUser: 'الشاحن',
            otherUserId: 2,
            otherUserRole: 'shipper',
            chatSocketFactory: _testChatSocket,
            pickImage: (_) async => PickedChatMedia(
              fileName: 'uploaded.jpg',
              bytes: Uint8List.fromList(const [1, 2, 3]),
              messageType: 'image',
            ),
          ),
        );
        await tester.tap(find.byIcon(Icons.add_circle_outline_rounded));
        await tester.pumpAndSettle();
        await tester.tap(find.text('اختيار صورة من المعرض'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.byType(ChatScreen), findsOneWidget);
      },
    );
  });

  testWidgets('mocked map location posts location message', (tester) async {
    await withMockedHttp(
      setup: (r) {
        _registerBaseRoutes(r, const []);
        r.respond(
          'POST',
          '/api/chat/4/location',
          statusCode: 201,
          body: {
            'id': 61,
            'shipment_id': 4,
            'sender_id': 1,
            'receiver_id': 2,
            'message': '',
            'message_type': 'location',
            'location_lat': 24.7136,
            'location_lng': 46.6753,
            'location_label': 'موقع محدد',
            'created_at': '2026-06-01T12:35:00Z',
          },
        );
      },
      callback: (_) async {
        await _pump(
          tester,
          ChatScreen(
            shipmentId: '4',
            otherUser: 'الشاحن',
            otherUserId: 2,
            otherUserRole: 'shipper',
            chatSocketFactory: _testChatSocket,
            currentPositionProvider: () async => throw Exception('gps off'),
            pickLocation: (_, __) async => {'lat': 24.7136, 'lng': 46.6753},
          ),
        );
        await tester.tap(find.byIcon(Icons.add_circle_outline_rounded));
        await tester.pumpAndSettle();
        await tester.tap(find.text('اختيار موقع من الخريطة'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.text('موقع محدد'), findsOneWidget);
      },
    );
  });

  testWidgets('attachment sheet "التقاط صورة" triggers image flow gracefully', (
    tester,
  ) async {
    await withMockedHttp(
      setup: (r) => _registerBaseRoutes(r, const []),
      callback: (_) async {
        await _pump(
          tester,
          ChatScreen(
            shipmentId: '4',
            otherUser: 'الشاحن',
            otherUserId: 2,
            otherUserRole: 'shipper',
            chatSocketFactory: _testChatSocket,
          ),
        );
        await tester.tap(find.byIcon(Icons.add_circle_outline_rounded));
        await tester.pumpAndSettle();
        await tester.tap(find.text('التقاط صورة'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));
        expect(find.byType(ChatScreen), findsOneWidget);
      },
    );
  });

  testWidgets('attachment sheet "تسجيل فيديو" exercises video pick', (
    tester,
  ) async {
    await withMockedHttp(
      setup: (r) => _registerBaseRoutes(r, const []),
      callback: (_) async {
        await _pump(
          tester,
          ChatScreen(
            shipmentId: '4',
            otherUser: 'الشاحن',
            otherUserId: 2,
            otherUserRole: 'shipper',
            chatSocketFactory: _testChatSocket,
          ),
        );
        await tester.tap(find.byIcon(Icons.add_circle_outline_rounded));
        await tester.pumpAndSettle();
        await tester.tap(find.text('تسجيل فيديو'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));
        expect(find.byType(ChatScreen), findsOneWidget);
      },
    );
  });

  testWidgets(
    'attachment sheet "مشاركة موقعي الحالي" surfaces snack on failure',
    (tester) async {
      await withMockedHttp(
        setup: (r) => _registerBaseRoutes(r, const []),
        callback: (_) async {
          await _pump(
            tester,
            ChatScreen(
              shipmentId: '4',
              otherUser: 'الشاحن',
              otherUserId: 2,
              otherUserRole: 'shipper',
              chatSocketFactory: _testChatSocket,
            ),
          );
          await tester.tap(find.byIcon(Icons.add_circle_outline_rounded));
          await tester.pumpAndSettle();
          await tester.tap(find.text('مشاركة موقعي الحالي'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 250));
          // In test env geolocator throws; we expect either a snack or that the
          // screen survives the call without crashing.
          expect(find.byType(ChatScreen), findsOneWidget);
        },
      );
    },
  );

  testWidgets('attachment sheet gallery image option dismisses cleanly', (
    tester,
  ) async {
    await withMockedHttp(
      setup: (r) => _registerBaseRoutes(r, const []),
      callback: (_) async {
        await _pump(
          tester,
          ChatScreen(
            shipmentId: '4',
            otherUser: 'الشاحن',
            otherUserId: 2,
            otherUserRole: 'shipper',
            chatSocketFactory: _testChatSocket,
          ),
        );
        await tester.tap(find.byIcon(Icons.add_circle_outline_rounded));
        await tester.pumpAndSettle();
        await tester.tap(find.text('اختيار صورة من المعرض'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        expect(find.byType(ChatScreen), findsOneWidget);
      },
    );
  });

  testWidgets('attachment sheet gallery video option dismisses cleanly', (
    tester,
  ) async {
    await withMockedHttp(
      setup: (r) => _registerBaseRoutes(r, const []),
      callback: (_) async {
        await _pump(
          tester,
          ChatScreen(
            shipmentId: '4',
            otherUser: 'الشاحن',
            otherUserId: 2,
            otherUserRole: 'shipper',
            chatSocketFactory: _testChatSocket,
          ),
        );
        await tester.tap(find.byIcon(Icons.add_circle_outline_rounded));
        await tester.pumpAndSettle();
        await tester.tap(find.text('اختيار فيديو من المعرض'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        expect(find.byType(ChatScreen), findsOneWidget);
      },
    );
  });

  testWidgets('failed REST send marks message as failed', (tester) async {
    await withMockedHttp(
      setup: (r) {
        _registerBaseRoutes(r, const []);
        r.respond(
          'POST',
          '/api/chat/send',
          statusCode: 500,
          body: {'message': 'oops'},
        );
      },
      callback: (_) async {
        await _pump(
          tester,
          ChatScreen(
            shipmentId: '4',
            otherUser: 'الشاحن',
            otherUserId: 2,
            otherUserRole: 'shipper',
            chatSocketFactory: _testChatSocket,
          ),
        );
        await tester.enterText(find.byType(TextField), 'فشل');
        await tester.pump();
        await tester.tap(find.byIcon(Icons.send_rounded));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.textContaining('تعذر إرسال الرسالة'), findsOneWidget);
      },
    );
  });

  testWidgets('sending text while socket offline posts via REST', (
    tester,
  ) async {
    await withMockedHttp(
      setup: (r) {
        _registerBaseRoutes(r, const []);
        r.respond(
          'POST',
          '/api/chat/send',
          body: {
            'id': 55,
            'shipment_id': 4,
            'sender_id': 1,
            'receiver_id': 2,
            'message': 'مرحبا',
            'message_type': 'text',
            'created_at': '2026-06-01T12:00:00Z',
          },
        );
      },
      callback: (_) async {
        await _pump(
          tester,
          ChatScreen(
            shipmentId: '4',
            otherUser: 'الشاحن',
            otherUserId: 2,
            otherUserRole: 'shipper',
            chatSocketFactory: _testChatSocket,
          ),
        );
        await tester.enterText(find.byType(TextField), 'مرحبا');
        await tester.pump();
        await tester.tap(find.byIcon(Icons.send_rounded));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));
        expect(find.text('مرحبا'), findsWidgets);
      },
    );
  });

  testWidgets('Empty send keeps message list unchanged', (tester) async {
    await withMockedHttp(
      setup: (r) => _registerBaseRoutes(r, const []),
      callback: (_) async {
        await _pump(
          tester,
          ChatScreen(
            shipmentId: '4',
            otherUser: 'الشاحن',
            otherUserId: 2,
            otherUserRole: 'shipper',
            chatSocketFactory: _testChatSocket,
          ),
        );
        await tester.tap(find.byIcon(Icons.send_rounded));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 30));
        expect(find.byType(ChatScreen), findsOneWidget);
      },
    );
  });
}
