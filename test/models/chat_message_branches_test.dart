import 'package:flutter_test/flutter_test.dart';
import 'package:darbak/models/chat_message.dart';

void main() {
  group('ChatMessage.fromJson — type inference branches', () {
    test('keeps text type when no media hints exist', () {
      final msg = ChatMessage.fromJson({
        'id': 1,
        'shipment_id': 5,
        'sender_id': 1,
        'receiver_id': 2,
        'message': 'hi',
        'message_type': 'TEXT',
      });
      expect(msg.messageType, 'text');
      expect(msg.isText, isTrue);
      expect(msg.isImage, isFalse);
      expect(msg.isVideo, isFalse);
    });

    test('detects image by media_url extension when mime is missing', () {
      final msg = ChatMessage.fromJson({
        'message_type': 'text',
        'media_url': 'https://cdn.test/path/asset.JPEG?token=1',
      });
      expect(msg.isImage, isTrue);
      expect(msg.messageType, 'image');
    });

    test('detects video by .m4v in URL even with image message_type', () {
      final msg = ChatMessage.fromJson({
        'message_type': 'image',
        'media_url': 'https://cdn.test/clip.m4v',
      });
      expect(msg.isVideo, isTrue);
    });

    test('detects video by .webp does NOT mark video', () {
      final msg = ChatMessage.fromJson({
        'media_file_name': 'asset.WEBP',
      });
      expect(msg.isImage, isTrue);
      expect(msg.isVideo, isFalse);
    });

    test('lowercases message_type and respects raw image value', () {
      final msg = ChatMessage.fromJson({
        'messageType': 'IMAGE',
      });
      expect(msg.messageType, 'image');
    });

    test('falls back to text for unknown raw type without media hints', () {
      final msg = ChatMessage.fromJson({'message_type': 'sticker'});
      expect(msg.messageType, 'text');
    });

    test('isDelivered is true when read_at is set even without delivered_at', () {
      final msg = ChatMessage.fromJson({
        'id': 1,
        'shipment_id': 1,
        'sender_id': 1,
        'receiver_id': 2,
        'read_at': '2026-05-25T10:00:00Z',
      });
      expect(msg.isRead, isTrue);
      expect(msg.isDelivered, isTrue);
    });

    test('parses sender_profile_image_key/url and trims blanks to null', () {
      final msg = ChatMessage.fromJson({
        'sender_profile_image_key': 'avatars/a.png',
        'sender_profile_image_url': '  https://cdn.test/a.png  ',
        'sender_name': '   ',
      });
      expect(msg.senderProfileImageKey, 'avatars/a.png');
      expect(msg.senderProfileImageUrl, 'https://cdn.test/a.png');
      expect(msg.senderName, isNull);
    });

    test('parses created_at into a local DateTime', () {
      final msg = ChatMessage.fromJson({
        'created_at': '2026-05-25T10:00:00Z',
      });
      expect(msg.createdAt, isNotNull);
      expect(msg.createdAt!.isUtc, isFalse);
    });

    test('returns null DateTime for empty/invalid date strings', () {
      final msg = ChatMessage.fromJson({
        'created_at': '   ',
        'delivered_at': 'not-a-date',
      });
      expect(msg.createdAt, isNull);
      expect(msg.deliveredAt, isNull);
    });

    test('coerces numeric strings via _intOrNull and _doubleOrNull', () {
      final msg = ChatMessage.fromJson({
        'shipment_id': 12.0,
        'sender_id': '7',
        'media_size_bytes': '2048',
        'location_lat': 24,
        'location_lng': '46.7',
      });
      expect(msg.shipmentId, 12);
      expect(msg.senderId, 7);
      expect(msg.mediaSizeBytes, 2048);
      expect(msg.locationLat, 24);
      expect(msg.locationLng, 46.7);
    });

    test('extracts clientMessageId when provided', () {
      final msg = ChatMessage.fromJson({'clientMessageId': 'tx-1'});
      expect(msg.clientMessageId, 'tx-1');
    });
  });

  group('ChatMessage status flags', () {
    test('isSent is false while pending or failed', () {
      const baseId = 7;
      final now = DateTime(2026, 1, 1);
      final pending = ChatMessage(
        id: baseId,
        shipmentId: 1,
        senderId: 1,
        receiverId: 2,
        message: 'x',
        createdAt: now,
        isPending: true,
      );
      final failed = ChatMessage(
        id: baseId,
        shipmentId: 1,
        senderId: 1,
        receiverId: 2,
        message: 'x',
        createdAt: now,
        hasFailed: true,
      );
      expect(pending.isSent, isFalse);
      expect(failed.isSent, isFalse);
    });

    test('isSent is false when id is null', () {
      final draft = ChatMessage(
        id: null,
        shipmentId: 1,
        senderId: 1,
        receiverId: 2,
        message: 'x',
        createdAt: DateTime(2026, 1, 1),
      );
      expect(draft.isSent, isFalse);
    });
  });

  group('ChatMessage.copyWith complete coverage', () {
    test('overrides every field independently', () {
      final base = ChatMessage(
        id: 1,
        shipmentId: 2,
        senderId: 3,
        receiverId: 4,
        message: 'm',
        createdAt: DateTime(2026, 1, 1),
        messageType: 'text',
      );

      final copy = base.copyWith(
        id: 99,
        shipmentId: 100,
        senderId: 101,
        receiverId: 102,
        message: 'updated',
        createdAt: DateTime(2027),
        messageType: 'image',
        mediaKey: 'mk',
        mediaUrl: 'mu',
        mediaMimeType: 'image/png',
        mediaSizeBytes: 512,
        mediaFileName: 'a.png',
        thumbnailKey: 'tk',
        thumbnailUrl: 'tu',
        locationLat: 1.0,
        locationLng: 2.0,
        locationLabel: 'الرياض',
        deliveredAt: DateTime(2028),
        readAt: DateTime(2029),
        senderName: 'علي',
        senderRole: 'driver',
        senderProfileImageKey: 'spk',
        senderProfileImageUrl: 'spu',
        clientMessageId: 'cmi',
        isPending: true,
        hasFailed: true,
      );

      expect(copy.id, 99);
      expect(copy.shipmentId, 100);
      expect(copy.message, 'updated');
      expect(copy.messageType, 'image');
      expect(copy.mediaKey, 'mk');
      expect(copy.thumbnailUrl, 'tu');
      expect(copy.locationLat, 1.0);
      expect(copy.isPending, isTrue);
      expect(copy.hasFailed, isTrue);
    });
  });

  group('ChatStatusUpdate and ChatMessageReceipt', () {
    test('fromJson without messages list returns empty list', () {
      final update = ChatStatusUpdate.fromJson({'shipmentId': 1});
      expect(update.shipmentId, 1);
      expect(update.messages, isEmpty);
    });

    test('reads shipment_id when shipmentId is missing', () {
      final update = ChatStatusUpdate.fromJson({
        'shipment_id': '5',
        'messages': <dynamic>[],
      });
      expect(update.shipmentId, 5);
    });

    test('parses receipts with delivered_at/read_at timestamps', () {
      final r = ChatMessageReceipt.fromJson({
        'id': 1,
        'shipment_id': 5,
        'sender_id': 7,
        'receiver_id': 9,
        'delivered_at': '2026-05-25T10:00:00Z',
        'read_at': null,
      });

      expect(r.id, 1);
      expect(r.shipmentId, 5);
      expect(r.senderId, 7);
      expect(r.receiverId, 9);
      expect(r.deliveredAt, isNotNull);
      expect(r.readAt, isNull);
    });
  });

  group('ChatMessageSent', () {
    test('stores the wrapped message and optional clientMessageId', () {
      final msg = ChatMessage(
        id: 1,
        shipmentId: 2,
        senderId: 3,
        receiverId: 4,
        message: 'hi',
        createdAt: DateTime(2026, 1, 1),
      );

      final sent = ChatMessageSent(message: msg, clientMessageId: 'cid');
      expect(sent.message, msg);
      expect(sent.clientMessageId, 'cid');

      final withoutCid = ChatMessageSent(message: msg);
      expect(withoutCid.clientMessageId, isNull);
    });
  });
}
