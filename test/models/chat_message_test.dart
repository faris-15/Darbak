import 'package:flutter_test/flutter_test.dart';
import 'package:darbak/models/chat_message.dart';

void main() {
  group('ChatMessage.fromJson', () {
    test('parses text message payload and status flags', () {
      final msg = ChatMessage.fromJson({
        'id': '1',
        'shipment_id': '10',
        'sender_id': '20',
        'receiver_id': '30',
        'message': 'مرحبا',
        'message_type': 'text',
        'created_at': '2026-05-25T10:00:00Z',
        'delivered_at': '2026-05-25T10:01:00Z',
        'sender_name': 'سائق',
      });

      expect(msg.id, 1);
      expect(msg.shipmentId, 10);
      expect(msg.senderId, 20);
      expect(msg.receiverId, 30);
      expect(msg.message, 'مرحبا');
      expect(msg.isText, isTrue);
      expect(msg.isSent, isTrue);
      expect(msg.isDelivered, isTrue);
      expect(msg.isRead, isFalse);
      expect(msg.senderName, 'سائق');
    });

    test('infers video type from mime, file name, and presigned URL', () {
      expect(
        ChatMessage.fromJson({
          'message_type': 'image',
          'media_mime_type': 'video/mp4',
        }).isVideo,
        isTrue,
      );
      expect(
        ChatMessage.fromJson({'media_file_name': 'clip.mov'}).messageType,
        'video',
      );
      expect(
        ChatMessage.fromJson({'media_url': 'https://x.test/file?response-content-type=video'})
            .isVideo,
        isTrue,
      );
    });

    test('infers image type from mime and extension', () {
      final msg = ChatMessage.fromJson({
        'message_type': 'text',
        'media_mime_type': 'image/png',
      });
      expect(msg.messageType, 'image');
      expect(msg.isImage, isTrue);
      expect(msg.isVideo, isFalse);
    });

    test('parses location payload', () {
      final msg = ChatMessage.fromJson({
        'message_type': 'location',
        'location_lat': '24.7136',
        'location_lng': 46.6753,
        'location_label': 'الرياض',
      });
      expect(msg.isLocation, isTrue);
      expect(msg.locationLat, 24.7136);
      expect(msg.locationLng, 46.6753);
      expect(msg.locationLabel, 'الرياض');
    });
  });

  test('copyWith overrides selected fields only', () {
    final original = ChatMessage(
      id: null,
      shipmentId: 1,
      senderId: 2,
      receiverId: 3,
      message: 'pending',
      createdAt: DateTime(2026),
      isPending: true,
    );

    final updated = original.copyWith(id: 99, isPending: false, message: 'sent');
    expect(updated.id, 99);
    expect(updated.message, 'sent');
    expect(updated.shipmentId, 1);
    expect(updated.isSent, isTrue);
  });

  test('ChatStatusUpdate parses receipt arrays and ignores invalid rows', () {
    final update = ChatStatusUpdate.fromJson({
      'shipmentId': '1000',
      'messages': [
        {'id': '1', 'shipment_id': '1000', 'sender_id': 1, 'receiver_id': 2},
        'bad',
      ],
    });

    expect(update.shipmentId, 1000);
    expect(update.messages, hasLength(1));
    expect(update.messages.first.id, 1);
  });
}
