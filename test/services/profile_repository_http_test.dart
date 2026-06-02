import 'dart:typed_data';

import 'package:darbak/services/profile_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/http_mock.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'user_id': 1,
      'user_role': 'driver',
      'auth_token': 't',
    });
  });

  group('ProfileRepository HTTP', () {
    test('getMe caches profile to prefs and notifier', () async {
      await withMockedHttp(
        setup: (r) => r.respond('GET', '/api/profile/me', body: {
          'data': {
            'id': 1,
            'full_name': 'Tester',
            'role': 'driver',
            'email': 't@test.io',
            'profileImageUrl': 'https://cdn.test/p.png',
            'profileImageKey': 'k1',
            'verification_status': 'verified',
          }
        }),
        callback: (_) async {
          final profile = await ProfileRepository.getMe();
          expect(profile['full_name'], 'Tester');
          final prefs = await SharedPreferences.getInstance();
          expect(prefs.getString('user_name'), 'Tester');
          expect(prefs.getString('verification_status'), 'verified');
        },
      );
    });

    test('updateProfile posts and caches result', () async {
      await withMockedHttp(
        setup: (r) => r.respond('PUT', '/api/profile/update', body: {
          'data': {
            'id': 1,
            'full_name': 'Updated',
            'role': 'driver',
            'email': 't@test.io',
          }
        }),
        callback: (_) async {
          final updated = await ProfileRepository.updateProfile({
            'fullName': 'Updated',
          });
          expect(updated['full_name'], 'Updated');
        },
      );
    });

    test('uploadProfileImage updates notifier', () async {
      await withMockedHttp(
        setup: (r) => r.respond('POST', '/api/profile/upload-image', body: {
          'profileImageUrl': 'https://cdn.test/new.png',
          'profileImageKey': 'new-key',
        }),
        callback: (_) async {
          final res = await ProfileRepository.uploadProfileImage(
            fileName: 'avatar.png',
            bytes: Uint8List.fromList([1, 2, 3]),
          );
          expect(res['profileImageUrl'], 'https://cdn.test/new.png');
          expect(ProfileRepository.profileImageNotifier.value.imageUrl,
              'https://cdn.test/new.png');
        },
      );
    });

    test('removeProfileImage clears notifier', () async {
      ProfileRepository.profileImageNotifier.value = const ProfileImageState(
        imageUrl: 'https://cdn.test/old.png',
        imageKey: 'old',
      );
      await withMockedHttp(
        setup: (r) =>
            r.respond('DELETE', '/api/profile/remove-image', body: {'ok': true}),
        callback: (_) async {
          await ProfileRepository.removeProfileImage();
          expect(
              ProfileRepository.profileImageNotifier.value.imageUrl, isNull);
        },
      );
    });

    test('hydrateFromPrefs loads stored image metadata', () async {
      SharedPreferences.setMockInitialValues({
        'profile_image_url': 'https://cdn.test/h.png',
        'profile_image_key': 'hk',
        'user_role': 'shipper',
      });
      await ProfileRepository.hydrateFromPrefs();
      expect(ProfileRepository.profileImageNotifier.value.imageUrl,
          'https://cdn.test/h.png');
      expect(ProfileRepository.profileImageNotifier.value.role, 'shipper');
    });
  });
}
