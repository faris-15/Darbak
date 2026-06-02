import 'package:darbak/services/profile_image_flow.dart';
import 'package:darbak/services/profile_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/http_mock.dart';

void main() {
  group('ProfileImageFlow.hasImage', () {
    test('returns true when camelCase URL is present', () {
      expect(
        ProfileImageFlow.hasImage({'profileImageUrl': 'https://x.test/a.png'}),
        isTrue,
      );
    });

    test('returns true when snake_case URL is present', () {
      expect(
        ProfileImageFlow.hasImage({
          'profile_image_url': 'https://x.test/a.png',
        }),
        isTrue,
      );
    });

    test('returns false for null user', () {
      expect(ProfileImageFlow.hasImage(null), isFalse);
    });

    test('returns false for empty/whitespace URLs', () {
      expect(ProfileImageFlow.hasImage({'profileImageUrl': ''}), isFalse);
      expect(ProfileImageFlow.hasImage({'profile_image_url': '   '}), isFalse);
      expect(ProfileImageFlow.hasImage({}), isFalse);
    });
  });

  group('ProfileImageFlow.applyToProfile', () {
    test('overlays uploaded URL/key onto an existing user map', () {
      final user = {
        'id': 1,
        'full_name': 'سائق',
        'profileImageUrl': 'https://old.test/a.png',
      };

      final next = ProfileImageFlow.applyToProfile(
        user,
        const ProfileImageChange(
          imageUrl: 'https://new.test/b.png',
          imageKey: 'k-1',
        ),
      );

      expect(next['id'], 1);
      expect(next['full_name'], 'سائق');
      expect(next['profileImageUrl'], 'https://new.test/b.png');
      expect(next['profile_image_url'], 'https://new.test/b.png');
      expect(next['profileImageKey'], 'k-1');
    });

    test('clears URL/key when removed is true', () {
      final next = ProfileImageFlow.applyToProfile({
        'id': 1,
        'profileImageUrl': 'old',
      }, const ProfileImageChange(removed: true));

      expect(next['profileImageUrl'], isNull);
      expect(next['profile_image_url'], isNull);
      expect(next['profileImageKey'], isNull);
    });

    test('starts from an empty map when user is null', () {
      final next = ProfileImageFlow.applyToProfile(
        null,
        const ProfileImageChange(
          imageUrl: 'https://x.test/c.png',
          imageKey: 'k-2',
        ),
      );

      expect(next.keys, containsAll(['profileImageUrl', 'profileImageKey']));
      expect(next['profileImageUrl'], 'https://x.test/c.png');
    });
  });

  group('ProfileImageChange', () {
    test('defaults removed to false and exposes constructor values', () {
      const change = ProfileImageChange(imageUrl: 'u', imageKey: 'k');

      expect(change.imageUrl, 'u');
      expect(change.imageKey, 'k');
      expect(change.removed, isFalse);
    });
  });

  test('ProfileImageAction enum exposes camera/gallery/remove', () {
    expect(ProfileImageAction.values, [
      ProfileImageAction.camera,
      ProfileImageAction.gallery,
      ProfileImageAction.remove,
    ]);
  });

  test(
    'uploadFromAction returns null for remove without invoking pickers',
    () async {
      final result = await ProfileImageFlow.uploadFromAction(
        ProfileImageAction.remove,
      );
      expect(result, isNull);
    },
  );

  test(
    'remove calls repository, clears cached image state, and returns removed change',
    () async {
      SharedPreferences.setMockInitialValues({
        'profile_image_url': 'https://cdn.test/old.png',
        'profile_image_key': 'profile/old.png',
        'user_role': 'driver',
      });
      ProfileRepository.profileImageNotifier.value = const ProfileImageState(
        imageUrl: 'https://cdn.test/old.png',
        imageKey: 'profile/old.png',
        role: 'driver',
      );

      await withMockedHttp(
        setup: (router) {
          router.respond(
            'DELETE',
            '/api/profile/remove-image',
            body: {'success': true},
          );
        },
        callback: (router) async {
          final change = await ProfileImageFlow.remove();
          final prefs = await SharedPreferences.getInstance();

          expect(change.removed, isTrue);
          expect(prefs.getString('profile_image_url'), isNull);
          expect(prefs.getString('profile_image_key'), isNull);
          expect(ProfileRepository.profileImageNotifier.value.imageUrl, isNull);
          expect(router.requests.single.method, 'DELETE');
        },
      );
    },
  );
}
