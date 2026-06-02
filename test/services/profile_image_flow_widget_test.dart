import 'package:darbak/services/profile_image_flow.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ProfileImageFlow', () {
    test('hasImage detects camelCase and snake_case keys', () {
      expect(
        ProfileImageFlow.hasImage({'profileImageUrl': 'https://x.test/a.png'}),
        isTrue,
      );
      expect(
        ProfileImageFlow.hasImage({'profile_image_url': 'https://x.test/a.png'}),
        isTrue,
      );
      expect(ProfileImageFlow.hasImage({'profileImageUrl': '  '}), isFalse);
      expect(ProfileImageFlow.hasImage(null), isFalse);
    });

    test('applyToProfile overlays or clears image fields', () {
      final updated = ProfileImageFlow.applyToProfile(
        {'id': 1, 'full_name': 'Tester'},
        const ProfileImageChange(
          imageUrl: 'https://cdn.test/n.png',
          imageKey: 'k',
        ),
      );
      expect(updated['profileImageUrl'], 'https://cdn.test/n.png');
      expect(updated['full_name'], 'Tester');

      final cleared = ProfileImageFlow.applyToProfile(
        updated,
        const ProfileImageChange(removed: true),
      );
      expect(cleared['profileImageUrl'], isNull);
      expect(cleared['profile_image_url'], isNull);
    });

    testWidgets('showActionSheet lists camera/gallery and optional remove',
        (tester) async {
      ProfileImageAction? picked;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    picked = await ProfileImageFlow.showActionSheet(
                      context,
                      hasImage: true,
                    );
                  },
                  child: const Text('open-sheet'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open-sheet'));
      await tester.pumpAndSettle();

      expect(find.text('التقاط صورة بالكاميرا'), findsOneWidget);
      expect(find.text('اختيار من المعرض'), findsOneWidget);
      expect(find.text('حذف الصورة'), findsOneWidget);

      await tester.tap(find.text('اختيار من المعرض'));
      await tester.pumpAndSettle();

      expect(picked, ProfileImageAction.gallery);
    });
  });
}
