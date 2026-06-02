import 'dart:typed_data';

import 'package:darbak/services/profile_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/http_mock.dart';

void main() {
  setUp(() {
    ProfileRepository.profileImageNotifier.value =
        const ProfileImageState();
  });

  group('ProfileImageState.copyWith', () {
    test('clearImage removes url and key', () {
      const state = ProfileImageState(
        imageUrl: 'https://x.test/a.png',
        imageKey: 'k1',
        role: 'driver',
      );
      final cleared = state.copyWith(clearImage: true);
      expect(cleared.imageUrl, isNull);
      expect(cleared.imageKey, isNull);
      expect(cleared.role, 'driver');
    });

    test('overrides role while keeping image fields', () {
      const state = ProfileImageState(
        imageUrl: 'https://x.test/a.png',
        imageKey: 'k1',
        role: 'driver',
      );
      final next = state.copyWith(role: 'shipper');
      expect(next.role, 'shipper');
      expect(next.imageUrl, 'https://x.test/a.png');
    });
  });

  group('ProfileRepository.hydrateFromPrefs', () {
    test('loads cached image url/key and role from prefs', () async {
      SharedPreferences.setMockInitialValues({
        'profile_image_url': 'https://cdn.test/u.png',
        'profile_image_key': 'profile/u.png',
        'user_role': 'shipper',
      });
      await ProfileRepository.hydrateFromPrefs();
      expect(
        ProfileRepository.profileImageNotifier.value.imageUrl,
        'https://cdn.test/u.png',
      );
      expect(
        ProfileRepository.profileImageNotifier.value.imageKey,
        'profile/u.png',
      );
      expect(ProfileRepository.profileImageNotifier.value.role, 'shipper');
    });
  });

  group('ProfileRepository.cacheProfile', () {
    test('persists user id as int, num, or string', () async {
      SharedPreferences.setMockInitialValues({});

      await ProfileRepository.cacheProfile({
        'id': 42,
        'role': 'driver',
        'full_name': 'Ali',
        'email': 'a@x.io',
        'verification_status': 'verified',
        'profileImageUrl': 'https://cdn.test/p.png',
        'profileImageKey': 'profile/p.png',
      });
      var prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('user_id'), 42);
      expect(prefs.getString('user_role'), 'driver');
      expect(prefs.getString('verification_status'), 'verified');

      await ProfileRepository.cacheProfile({'id': 7.0, 'role': 'shipper'});
      prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('user_id'), 7);

      await ProfileRepository.cacheProfile({'id': '99', 'role': 'driver'});
      prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('user_id'), 99);
    });
  });

  group('ProfileRepository.uploadProfileImage', () {
    test('uploads bytes and updates notifier', () async {
      SharedPreferences.setMockInitialValues({'auth_token': 't'});
      await withMockedHttp(
        setup: (r) => r.respond('POST', '/api/profile/upload-image', body: {
          'profileImageUrl': 'https://cdn.test/new.png',
          'profileImageKey': 'profile/new.png',
        }),
        callback: (_) async {
          final response = await ProfileRepository.uploadProfileImage(
            fileName: 'avatar.png',
            bytes: Uint8List.fromList(List.filled(32, 1)),
          );
          expect(response['profileImageUrl'], 'https://cdn.test/new.png');
          expect(
            ProfileRepository.profileImageNotifier.value.imageUrl,
            'https://cdn.test/new.png',
          );
        },
      );
    });
  });

  group('ProfileRepository.stableCacheKey', () {
    test('prefers imageKey prefix when key is present', () {
      expect(
        ProfileRepository.stableCacheKey('profile/abc.png', 'https://x.test/a'),
        'profile-image:profile/abc.png',
      );
    });

    test('falls back to cleaned url when key is empty', () {
      expect(
        ProfileRepository.stableCacheKey(null, 'https://x.test/a.png'),
        'https://x.test/a.png',
      );
    });

    test('returns null for blank values', () {
      expect(ProfileRepository.stableCacheKey('  ', 'null'), isNull);
    });
  });

  group('ProfileRepository.preloadProfileImage', () {
    test('returns immediately when url is blank', () async {
      await ProfileRepository.preloadProfileImage(
        imageUrl: null,
        imageKey: null,
      );
      await ProfileRepository.preloadProfileImage(
        imageUrl: '   ',
        imageKey: 'k',
      );
    });
  });
}
