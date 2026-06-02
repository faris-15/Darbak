import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shimmer/shimmer.dart';

import 'package:darbak/models/review_target_profile.dart';
import 'package:darbak/widgets/review_target_profile_card.dart';

import '../helpers/test_app.dart';

void main() {
  group('ReviewTargetProfileCard', () {
    testWidgets('renders the shimmer skeleton when loading', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const Scaffold(
            body: ReviewTargetProfileCard(
              isLoading: true,
              profile: null,
              fallbackName: 'سائق',
              fallbackRoleLabel: 'سائق',
            ),
          ),
        ),
      );

      expect(find.byType(Shimmer), findsOneWidget);
    });

    testWidgets('renders profile name, role and initial when no image is available', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const Scaffold(
            body: ReviewTargetProfileCard(
              isLoading: false,
              profile: ReviewTargetProfile(
                id: 1,
                name: 'أحمد',
                role: 'driver',
                roleLabelAr: 'سائق',
              ),
              fallbackName: 'سائق',
              fallbackRoleLabel: 'سائق',
            ),
          ),
        ),
      );

      expect(find.text('أحمد'), findsOneWidget);
      expect(find.text('سائق'), findsOneWidget);
      expect(find.text('أ'), findsOneWidget);
    });

    testWidgets('falls back to provided fallback name when profile name is empty', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const Scaffold(
            body: ReviewTargetProfileCard(
              isLoading: false,
              profile: ReviewTargetProfile(
                id: 1,
                name: '',
                role: 'driver',
                roleLabelAr: '',
              ),
              fallbackName: 'مستخدم احتياطي',
              fallbackRoleLabel: 'سائق احتياطي',
            ),
          ),
        ),
      );

      expect(find.text('مستخدم احتياطي'), findsOneWidget);
      expect(find.text('سائق احتياطي'), findsOneWidget);
    });

    testWidgets('uses fallback name initial when profile is null', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const Scaffold(
            body: ReviewTargetProfileCard(
              isLoading: false,
              profile: null,
              fallbackName: 'بدون اسم',
              fallbackRoleLabel: 'شركة',
            ),
          ),
        ),
      );

      expect(find.text('بدون اسم'), findsOneWidget);
      expect(find.text('شركة'), findsOneWidget);
      expect(find.text('ب'), findsOneWidget);
    });
  });
}
