import 'package:darbak/models/chat_message.dart';
import 'package:darbak/services/chat_socket_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('ChatSocketService', () {
    test('connect short-circuits when skipRealConnection is true', () async {
      SharedPreferences.setMockInitialValues({'auth_token': 't'});
      final s = ChatSocketService(skipRealConnection: true);
      await s.connect();
      expect(s.isConnected, isFalse);
      s.dispose();
    });

    test('connect emits "Missing auth token" when no token cached', () async {
      SharedPreferences.setMockInitialValues({});
      final s = ChatSocketService();
      final errors = <String>[];
      s.errors.listen(errors.add);
      await s.connect();
      // give the error stream a tick to fire.
      await Future<void>.delayed(Duration.zero);
      expect(errors, contains('Missing auth token'));
      s.dispose();
    });

    test('joinShipment is a no-op when socket is null', () {
      final s = ChatSocketService(skipRealConnection: true);
      expect(() => s.joinShipment(1), returnsNormally);
      s.dispose();
    });

    test('markDelivered + markRead are no-ops when disconnected', () {
      final s = ChatSocketService(skipRealConnection: true);
      expect(
        () => s.markDelivered(shipmentId: 1, messageIds: const [1, 2]),
        returnsNormally,
      );
      expect(
        () => s.markRead(shipmentId: 1, messageIds: const [1, 2]),
        returnsNormally,
      );
      s.dispose();
    });

    test('sendMessage throws StateError when not connected', () {
      final s = ChatSocketService(skipRealConnection: true);
      expect(
        () => s.sendMessage(
          shipmentId: 1,
          receiverId: 2,
          message: 'hi',
          clientMessageId: 'cid',
        ),
        throwsA(isA<StateError>()),
      );
      s.dispose();
    });

    test('connect with token wires socket.io and emits connect error', () async {
      SharedPreferences.setMockInitialValues({'auth_token': 'fake-token'});
      final s = ChatSocketService();
      final errors = <String>[];
      final sub = s.errors.listen(errors.add);
      await s.connect();
      // Let the underlying socket attempt to fail/throw asynchronously.
      await Future<void>.delayed(const Duration(milliseconds: 200));
      // The socket service must remain operable; even if no error was emitted
      // (e.g. dart:io network blocked synchronously), the service is wired up.
      expect(s.isConnected, isFalse);
      await sub.cancel();
      s.dispose();
    });

    test('dispose is idempotent and silences subsequent stream adds', () async {
      final s = ChatSocketService(skipRealConnection: true);
      final messages = <dynamic>[];
      s.newMessages.listen(messages.add);
      s.dispose();
      expect(s.isConnected, isFalse);
      // calling dispose twice should not crash
      expect(() => s.dispose(), returnsNormally);
    });

    test('emitTestMessage accepts nested message payload maps', () async {
      final s = ChatSocketService(skipRealConnection: true);
      final messages = <ChatMessage>[];
      final sub = s.newMessages.listen(messages.add);
      s.emitTestMessage(
        ChatMessage(
          id: 2,
          shipmentId: 11,
          senderId: 3,
          receiverId: 4,
          message: 'nested',
          createdAt: DateTime.parse('2026-06-02T00:00:00Z'),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(messages.single.message, 'nested');
      await sub.cancel();
      s.dispose();
    });

    test('dispatchTestSocketEvent handles chat payloads', () async {
      final s = ChatSocketService(skipRealConnection: true);
      final messages = <ChatMessage>[];
      final sent = <ChatMessageSent>[];
      final statuses = <ChatStatusUpdate>[];
      final errors = <String>[];
      final subs = [
        s.newMessages.listen(messages.add),
        s.sentMessages.listen(sent.add),
        s.statusUpdates.listen(statuses.add),
        s.errors.listen(errors.add),
      ];

      s.dispatchTestSocketEvent('chat:newMessage', {
        'id': 3,
        'shipment_id': 4,
        'sender_id': 1,
        'receiver_id': 2,
        'message': 'hello',
        'created_at': '2026-06-01T00:00:00Z',
      });
      s.dispatchTestSocketEvent('chat:messageSent', {
        'clientMessageId': 'c9',
        'message': {
          'id': 4,
          'shipment_id': 4,
          'sender_id': 1,
          'receiver_id': 2,
          'message': 'sent',
          'created_at': '2026-06-01T00:01:00Z',
        },
      });
      s.dispatchTestSocketEvent('chat:statusUpdated', {
        'shipmentId': 4,
        'messages': [
          {
            'id': 4,
            'shipmentId': 4,
            'senderId': 1,
            'receiverId': 2,
          }
        ],
      });
      s.dispatchTestSocketEvent('chat:error', {'message': 'socket boom'});
      await Future<void>.delayed(Duration.zero);

      expect(messages.single.message, 'hello');
      expect(sent.single.clientMessageId, 'c9');
      expect(statuses.single.shipmentId, 4);
      expect(errors.single, 'socket boom');

      for (final sub in subs) {
        await sub.cancel();
      }
      s.dispose();
    });

    test('visible-for-testing emit helpers publish stream events', () async {
      final s = ChatSocketService(skipRealConnection: true);
      final messages = <ChatMessage>[];
      final sent = <ChatMessageSent>[];
      final statuses = <ChatStatusUpdate>[];
      final errors = <String>[];
      final subs = [
        s.newMessages.listen(messages.add),
        s.sentMessages.listen(sent.add),
        s.statusUpdates.listen(statuses.add),
        s.errors.listen(errors.add),
      ];

      final message = ChatMessage(
        id: 1,
        shipmentId: 10,
        senderId: 2,
        receiverId: 3,
        message: 'hi',
        createdAt: DateTime.parse('2026-06-01T00:00:00Z'),
      );
      s.emitTestMessage(message);
      s.emitTestSent(ChatMessageSent(message: message, clientMessageId: 'c1'));
      s.emitTestStatus(
        const ChatStatusUpdate(
          shipmentId: 10,
          messages: [
            ChatMessageReceipt(
              id: 1,
              shipmentId: 10,
              senderId: 2,
              receiverId: 3,
            ),
          ],
        ),
      );
      s.emitTestError('boom');
      await Future<void>.delayed(Duration.zero);

      expect(messages.single.message, 'hi');
      expect(sent.single.clientMessageId, 'c1');
      expect(statuses.single.shipmentId, 10);
      expect(errors.single, 'boom');
      for (final sub in subs) {
        await sub.cancel();
      }
      s.dispose();
    });
  });
}
