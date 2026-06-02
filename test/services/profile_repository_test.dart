import 'package:darbak/services/profile_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ProfileImageState', () {
    test('default state has nulls and driver role', () {
      const s = ProfileImageState();
      expect(s.imageUrl, isNull);
      expect(s.imageKey, isNull);
      expect(s.role, 'driver');
    });

    test('copyWith updates only specified fields', () {
      const original = ProfileImageState(
        imageUrl: 'https://x.test/a.png',
        imageKey: 'k1',
        role: 'driver',
      );

      final next = original.copyWith(role: 'shipper');

      expect(next.imageUrl, 'https://x.test/a.png');
      expect(next.imageKey, 'k1');
      expect(next.role, 'shipper');
    });

    test('copyWith with clearImage=true wipes image fields', () {
      const original = ProfileImageState(
        imageUrl: 'https://x.test/a.png',
        imageKey: 'k1',
        role: 'driver',
      );

      final cleared = original.copyWith(clearImage: true);

      expect(cleared.imageUrl, isNull);
      expect(cleared.imageKey, isNull);
      expect(cleared.role, 'driver');
    });

    test('copyWith preserves prior values when fields are omitted', () {
      const original = ProfileImageState(
        imageUrl: 'url',
        imageKey: 'key',
        role: 'driver',
      );

      final next = original.copyWith();

      expect(next.imageUrl, 'url');
      expect(next.imageKey, 'key');
      expect(next.role, 'driver');
    });
  });

  group('ProfileRepository.stableCacheKey', () {
    test('prefers the image key prefix when a key is provided', () {
      expect(
        ProfileRepository.stableCacheKey('  abc  ', 'https://x.test/a.png'),
        'profile-image:abc',
      );
    });

    test('falls back to the URL when the key is null or empty', () {
      expect(
        ProfileRepository.stableCacheKey(null, 'https://x.test/a.png'),
        'https://x.test/a.png',
      );
      expect(
        ProfileRepository.stableCacheKey('', 'https://x.test/a.png'),
        'https://x.test/a.png',
      );
      expect(
        ProfileRepository.stableCacheKey('   ', 'https://x.test/a.png'),
        'https://x.test/a.png',
      );
    });

    test('treats the literal string "null" as missing', () {
      expect(
        ProfileRepository.stableCacheKey('null', 'https://x.test/a.png'),
        'https://x.test/a.png',
      );
      expect(ProfileRepository.stableCacheKey('null', 'null'), isNull);
    });

    test('returns null when both inputs are empty/null', () {
      expect(ProfileRepository.stableCacheKey(null, null), isNull);
      expect(ProfileRepository.stableCacheKey('  ', '  '), isNull);
    });
  });

  test('profileImageNotifier exposes a default ProfileImageState', () {
    final state = ProfileRepository.profileImageNotifier.value;
    expect(state.role.isNotEmpty, isTrue);
  });
}
