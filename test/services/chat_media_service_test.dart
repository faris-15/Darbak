import 'dart:typed_data';

import 'package:darbak/api_service.dart';
import 'package:darbak/services/chat_media_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ChatMediaService.validateImage', () {
    test('accepts non-empty images up to the service max', () {
      expect(
        () => ChatMediaService.validateImage(byteLength: 1),
        returnsNormally,
      );
      expect(
        () => ChatMediaService.validateImage(
          byteLength: ApiService.maxChatImageBytes,
        ),
        returnsNormally,
      );
    });

    test('rejects empty image bytes', () {
      expect(
        () => ChatMediaService.validateImage(byteLength: 0),
        throwsA(
          isA<DarbakException>().having(
            (e) => e.message,
            'message',
            'الصورة فارغة',
          ),
        ),
      );
    });

    test('rejects oversized images', () {
      expect(
        () => ChatMediaService.validateImage(
          byteLength: ApiService.maxChatImageBytes + 1,
        ),
        throwsA(
          isA<DarbakException>().having(
            (e) => e.message,
            'message',
            contains('10 ميجابايت'),
          ),
        ),
      );
    });
  });

  group('ChatMediaService.validateVideo', () {
    test('accepts non-empty videos up to the service max', () {
      expect(
        () => ChatMediaService.validateVideo(byteLength: 1),
        returnsNormally,
      );
      expect(
        () => ChatMediaService.validateVideo(
          byteLength: ApiService.maxChatVideoBytes,
        ),
        returnsNormally,
      );
    });

    test('rejects empty video bytes', () {
      expect(
        () => ChatMediaService.validateVideo(byteLength: 0),
        throwsA(
          isA<DarbakException>().having(
            (e) => e.message,
            'message',
            'الفيديو فارغ',
          ),
        ),
      );
    });

    test('rejects oversized videos', () {
      expect(
        () => ChatMediaService.validateVideo(
          byteLength: ApiService.maxChatVideoBytes + 1,
        ),
        throwsA(
          isA<DarbakException>().having(
            (e) => e.message,
            'message',
            contains('50 ميجابايت'),
          ),
        ),
      );
    });
  });

  test('PickedChatMedia carries upload metadata', () {
    final media = PickedChatMedia(
      fileName: 'photo-1.jpg',
      bytes: Uint8List.fromList([1, 2]),
      messageType: 'image',
    );

    expect(media.fileName, 'photo-1.jpg');
    expect(media.bytes, [1, 2]);
    expect(media.messageType, 'image');
  });
}
