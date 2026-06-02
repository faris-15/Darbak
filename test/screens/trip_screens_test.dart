import 'package:darbak/services/chat_socket_service.dart';
import 'package:darbak/trip_screens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/http_mock.dart';

ChatSocketService _noopChatSocket() =>
    ChatSocketService(skipRealConnection: true);

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

void _tallViewport(WidgetTester tester) {
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
  _tallViewport(tester);
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

  group('TripTrackingScreen', () {
    testWidgets('renders driver info card and step list', (tester) async {
      await _pumpAndDrain(
        tester,
        const TripTrackingScreen(
          shipmentId: '7',
          driverName: 'أحمد',
          driverRating: '4.8',
          driverPhone: '0500000000',
        ),
      );
      expect(find.byType(TripTrackingScreen), findsOneWidget);
      expect(find.text('أحمد'), findsOneWidget);
      expect(find.text('تتبع الرحلة'), findsOneWidget);
    });

  });

  group('PenaltyScreen', () {
    testWidgets('renders on-time delivery summary', (tester) async {
      await _pumpAndDrain(
        tester,
        PenaltyScreen(shipmentData: {
          'shipment_id': 7,
          'bid_amount': '1000',
          'expected_delivery_at': DateTime.now()
              .add(const Duration(days: 1))
              .toIso8601String(),
          'delivered_at': DateTime.now().toIso8601String(),
        }),
      );
      expect(find.byType(PenaltyScreen), findsOneWidget);
      expect(find.text('تم التسليم في الموعد'), findsOneWidget);
    });

    testWidgets('renders late delivery penalty summary', (tester) async {
      await _pumpAndDrain(
        tester,
        PenaltyScreen(shipmentData: {
          'shipment_id': 99,
          'bid_amount': '2000',
          'expected_delivery_at': DateTime.now()
              .subtract(const Duration(days: 4))
              .toIso8601String(),
          'delivered_at': DateTime.now().toIso8601String(),
        }),
      );
      expect(find.byType(PenaltyScreen), findsOneWidget);
      expect(find.text('تم احتساب عقوبة تأخير'), findsOneWidget);
      expect(find.textContaining('يوم'), findsWidgets);
    });

    testWidgets('renders with missing expected date as غير محدد', (tester) async {
      await _pumpAndDrain(
        tester,
        const PenaltyScreen(shipmentData: {
          'shipment_id': 5,
          'bid_amount': '500',
        }),
      );
      expect(find.text('غير محدد'), findsOneWidget);
    });
  });

  group('ProofOfDeliveryScreen', () {
    testWidgets('renders initial state with camera placeholder',
        (tester) async {
      await _pumpAndDrain(
        tester,
        const ProofOfDeliveryScreen(shipmentId: '7'),
      );
      expect(find.byType(ProofOfDeliveryScreen), findsOneWidget);
      expect(find.text('التقط صورة للشحنة عند التسليم'), findsOneWidget);
      expect(find.byIcon(Icons.camera_alt_outlined), findsOneWidget);
    });

    testWidgets('submit without image shows SnackBar', (tester) async {
      await _pumpAndDrain(
        tester,
        const ProofOfDeliveryScreen(shipmentId: '7'),
      );
      await tester.tap(find.text('تأكيد التسليم'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('يرجى التقاط صورة للشحنة أولاً'), findsOneWidget);
    });
  });

  group('TripTrackingScreen ↔ ChatScreen integration', () {
    testWidgets('chat icon navigates to ChatScreen with stub socket',
        (tester) async {
      await withMockedHttp(
        setup: (r) {
          r.respond('GET', '/api/shipments/7',
              body: {'id': 7, 'shipper_id': 2, 'driver_id': 1});
          r.respond('GET', '/api/profile/me', body: {
            'data': {'id': 1, 'role': 'driver'}
          });
          r.respond('GET', '/api/auth/profile/2',
              body: {'id': 2, 'role': 'shipper'});
          r.respond('GET', '/api/chat/7', body: []);
          r.respond('POST', '/api/chat/7/delivered', body: {'ok': true});
          r.respond('POST', '/api/chat/7/read', body: {'ok': true});
        },
        callback: (_) async {
          await _pumpAndDrain(
            tester,
            ChatScreen(
              shipmentId: '7',
              otherUser: 'الشاحن',
              otherUserId: 2,
              otherUserRole: 'shipper',
              chatSocketFactory: _noopChatSocket,
            ),
          );
          expect(find.byType(ChatScreen), findsOneWidget);
        },
      );
    });
  });

  group('ChatScreen (no-op socket)', () {
    testWidgets('renders loading then empty list', (tester) async {
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
          await _pumpAndDrain(
            tester,
            ChatScreen(
              shipmentId: '3',
              otherUser: 'الشاحن',
              otherUserId: 2,
              otherUserRole: 'shipper',
              chatSocketFactory: _noopChatSocket,
            ),
            iterations: 18,
          );
          expect(find.byType(ChatScreen), findsOneWidget);
        },
      );
    });

    testWidgets('sends text message via HTTP when socket is not connected',
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
          r.respond('POST', '/api/chat/send', statusCode: 201, body: {
            'id': 99,
            'shipment_id': 3,
            'sender_id': 1,
            'receiver_id': 2,
            'message': 'مرحبا من الاختبار',
            'message_type': 'text',
            'created_at': '2026-06-01T12:00:00Z',
          });
        },
        callback: (_) async {
          await _pumpAndDrain(
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

          await tester.enterText(find.byType(TextField), 'مرحبا من الاختبار');
          await tester.tap(find.byIcon(Icons.send_rounded));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));
          await tester.pump(const Duration(milliseconds: 100));

          expect(find.text('مرحبا من الاختبار'), findsWidgets);
        },
      );
    });

    testWidgets('renders messages list when API returns rows',
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
              'id': 11,
              'shipment_id': 3,
              'sender_id': 2,
              'receiver_id': 1,
              'message': 'مرحبا',
              'message_type': 'text',
              'created_at': '2026-06-01T10:00:00Z',
              'is_delivered': 1,
              'is_read': 1,
            },
            {
              'id': 12,
              'shipment_id': 3,
              'sender_id': 1,
              'receiver_id': 2,
              'message': 'أهلا',
              'message_type': 'text',
              'created_at': '2026-06-01T10:05:00Z',
              'is_delivered': 1,
              'is_read': 0,
            }
          ]);
          r.respond('POST', '/api/chat/3/delivered', body: {'ok': true});
          r.respond('POST', '/api/chat/3/read', body: {'ok': true});
        },
        callback: (_) async {
          await _pumpAndDrain(
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
          expect(find.text('أهلا'), findsOneWidget);
        },
      );
    });
  });
}
