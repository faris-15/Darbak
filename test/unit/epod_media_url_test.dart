import 'package:darbak/epod_media_url.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EpodMediaUrl.extractLatestPhotoPathFromHistory', () {
    test('returns last non-empty photo_path', () {
      expect(
        EpodMediaUrl.extractLatestPhotoPathFromHistory([
          {'photo_path': ''},
          {'photo_path': 'a.jpg'},
          {'photo_path': 'b.jpg'},
        ]),
        'b.jpg',
      );
    });

    test('returns null when no paths', () {
      expect(EpodMediaUrl.extractLatestPhotoPathFromHistory([]), isNull);
      expect(
        EpodMediaUrl.extractLatestPhotoPathFromHistory([
          {'photo_path': ''},
        ]),
        isNull,
      );
    });
  });

  group('EpodMediaUrl.buildBackendImageUrl (S3 / storage resolution)', () {
    test('returns null for null or blank', () {
      expect(EpodMediaUrl.buildBackendImageUrl(null), isNull);
      expect(EpodMediaUrl.buildBackendImageUrl('  '), isNull);
    });

    test('passes through http(s) URLs', () {
      expect(
        EpodMediaUrl.buildBackendImageUrl('https://bucket.s3.amazonaws.com/x?sig=1'),
        'https://bucket.s3.amazonaws.com/x?sig=1',
      );
      expect(
        EpodMediaUrl.buildBackendImageUrl('http://localhost/epod.jpg'),
        'http://localhost/epod.jpg',
      );
    });

    test('prefixes absolute path with API origin', () {
      final u = EpodMediaUrl.buildBackendImageUrl('/static/epod.jpg')!;
      expect(u.startsWith('http://10.0.2.2:5000'), isTrue);
      expect(u.endsWith('/static/epod.jpg'), isTrue);
    });

    test('S3-style key uses admin signed-url proxy on API origin', () {
      final u = EpodMediaUrl.buildBackendImageUrl('epod/shipments/9.jpg')!;
      expect(u, contains('/api/admin/get-signed-url?url='));
      expect(u, contains(Uri.encodeComponent('epod/shipments/9.jpg')));
    });
  });
}
