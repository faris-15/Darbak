import 'package:flutter_test/flutter_test.dart';
import 'package:darbak/models/review_target_profile.dart';

void main() {
  group('ReviewTargetProfile.initialFor', () {
    test('returns ? for empty/whitespace names', () {
      expect(ReviewTargetProfile.initialFor(''), '?');
      expect(ReviewTargetProfile.initialFor('   '), '?');
    });

    test('returns first grapheme cluster for Arabic and Latin names', () {
      expect(ReviewTargetProfile.initialFor('أحمد العتيبي'), 'أ');
      expect(ReviewTargetProfile.initialFor('Alice Doe'), 'A');
    });

    test('handles names with leading whitespace', () {
      expect(ReviewTargetProfile.initialFor('  محمد'), 'م');
    });

    test('handles emoji/grapheme clusters as a single initial', () {
      final profile = ReviewTargetProfile(
        id: 1,
        name: '👨‍💼 محمد',
        role: 'driver',
        roleLabelAr: 'سائق',
      );
      expect(profile.nameInitial.runes, isNotEmpty);
    });
  });

  group('ReviewTargetProfile.fromJson', () {
    test('parses driver payload with snake_case fields', () {
      final p = ReviewTargetProfile.fromJson({
        'id': '42',
        'full_name': 'أحمد العتيبي',
        'profile_image_url': '  https://cdn.test/a.png  ',
        'profileImageKey': '  k123  ',
        'role': 'driver',
        'role_label_ar': 'سائق محترف',
      });

      expect(p.id, 42);
      expect(p.name, 'أحمد العتيبي');
      expect(p.profileImageUrl, 'https://cdn.test/a.png');
      expect(p.profileImageKey, 'k123');
      expect(p.role, 'driver');
      expect(p.roleLabelAr, 'سائق محترف');
      expect(p.nameInitial, 'أ');
    });

    test('parses shipper payload and falls back to default Arabic label', () {
      final p = ReviewTargetProfile.fromJson({
        'id': 9,
        'name': 'شركة دربك',
        'role': 'SHIPPER',
      });

      expect(p.role, 'shipper');
      expect(p.roleLabelAr, 'شركة');
    });

    test('coerces unknown roles to driver and uses driver label', () {
      final p = ReviewTargetProfile.fromJson({
        'id': 1,
        'name': 'Test',
        'role': 'admin',
      });
      expect(p.role, 'driver');
      expect(p.roleLabelAr, 'سائق');
    });

    test('uses camelCase profileImageUrl when snake_case is missing', () {
      final p = ReviewTargetProfile.fromJson({
        'id': 5,
        'name': 'User',
        'profileImageUrl': 'https://cdn.test/b.jpg',
      });
      expect(p.profileImageUrl, 'https://cdn.test/b.jpg');
    });

    test('treats empty image/key strings as null', () {
      final p = ReviewTargetProfile.fromJson({
        'id': 1,
        'name': 'User',
        'profile_image': '   ',
        'profileImageKey': '',
      });
      expect(p.profileImageUrl, isNull);
      expect(p.profileImageKey, isNull);
    });

    test('coerces invalid id strings to 0 and missing name to empty', () {
      final p = ReviewTargetProfile.fromJson({'id': 'NaN'});
      expect(p.id, 0);
      expect(p.name, '');
      expect(p.role, 'driver');
      expect(p.nameInitial, '?');
    });
  });
}
