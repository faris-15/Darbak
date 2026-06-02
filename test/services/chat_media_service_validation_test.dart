import 'dart:typed_data';

import 'package:darbak/api_service.dart';
import 'package:darbak/services/chat_media_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ChatMediaService.validateImage', () {
    test('accepts a small payload', () {
      expect(
        () => ChatMediaService.validateImage(byteLength: 1024),
        returnsNormally,
      );
    });

    test('rejects empty image', () {
      expect(
        () => ChatMediaService.validateImage(byteLength: 0),
        throwsA(isA<DarbakException>().having(
          (e) => e.message,
          'message',
          'الصورة فارغة',
        )),
      );
    });

    test('rejects oversize image', () {
      expect(
        () => ChatMediaService.validateImage(
          byteLength: ApiService.maxChatImageBytes + 1,
        ),
        throwsA(isA<DarbakException>().having(
          (e) => e.message,
          'message',
          contains('10 ميجابايت'),
        )),
      );
    });
  });

  group('ChatMediaService.validateVideo', () {
    test('rejects empty video', () {
      expect(
        () => ChatMediaService.validateVideo(byteLength: 0),
        throwsA(isA<DarbakException>().having(
          (e) => e.message,
          'message',
          'الفيديو فارغ',
        )),
      );
    });

    test('rejects oversize video', () {
      expect(
        () => ChatMediaService.validateVideo(
          byteLength: ApiService.maxChatVideoBytes + 1,
        ),
        throwsA(isA<DarbakException>().having(
          (e) => e.message,
          'message',
          contains('50 ميجابايت'),
        )),
      );
    });
  });

  group('PickedChatMedia', () {
    test('stores file metadata', () {
      final media = PickedChatMedia(
        fileName: 'clip.mp4',
        bytes: Uint8List(0),
        messageType: 'video',
      );
      expect(media.fileName, 'clip.mp4');
      expect(media.messageType, 'video');
    });
  });
}
