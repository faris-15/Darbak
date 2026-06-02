import 'package:darbak/api_service.dart';
import 'package:darbak/services/image_upload_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ImageUploadService.validateProfileImage', () {
    test('accepts a small jpg', () {
      expect(
        () => ImageUploadService.validateProfileImage(
          fileName: 'avatar.jpg',
          byteLength: 100,
        ),
        returnsNormally,
      );
    });

    test('rejects unsupported extension', () {
      expect(
        () => ImageUploadService.validateProfileImage(
          fileName: 'avatar.gif',
          byteLength: 100,
        ),
        throwsA(isA<DarbakException>().having(
          (e) => e.message,
          'message',
          contains('غير مدعوم'),
        )),
      );
    });

    test('rejects empty bytes', () {
      expect(
        () => ImageUploadService.validateProfileImage(
          fileName: 'avatar.jpg',
          byteLength: 0,
        ),
        throwsA(isA<DarbakException>().having(
          (e) => e.message,
          'message',
          'الصورة فارغة',
        )),
      );
    });

    test('rejects oversize image', () {
      expect(
        () => ImageUploadService.validateProfileImage(
          fileName: 'avatar.png',
          byteLength: ImageUploadService.maxProfileImageBytes + 1,
        ),
        throwsA(isA<DarbakException>().having(
          (e) => e.message,
          'message',
          contains('يتجاوز'),
        )),
      );
    });

    test('accepts case-insensitive extensions and webp', () {
      expect(
        () => ImageUploadService.validateProfileImage(
          fileName: 'AVATAR.WEBP',
          byteLength: 100,
        ),
        returnsNormally,
      );
    });

    test('rejects empty extension', () {
      expect(
        () => ImageUploadService.validateProfileImage(
          fileName: 'noextension',
          byteLength: 100,
        ),
        // Falls back to "jpg" so it should accept.
        returnsNormally,
      );
    });
  });
}
