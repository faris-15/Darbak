import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:darbak/truck_classification/truck_classification_catalog.dart';
import 'package:darbak/truck_classification/truck_classification_models.dart';
import 'package:darbak/truck_classification/widgets/truck_classification_dropdowns.dart';

import '../helpers/test_app.dart';

void main() {
  group('TruckGroupDropdown', () {
    testWidgets('shows all groups and reports selection changes', (tester) async {
      TruckGroup? selected;
      await tester.pumpWidget(
        buildTestApp(
          Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(24),
              child: TruckGroupDropdown(
                value: null,
                onChanged: (value) => selected = value,
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(DropdownButtonFormField<TruckGroup>));
      await tester.pumpAndSettle();

      for (final group in TruckGroup.values) {
        expect(find.text(group.labelAr), findsWidgets);
      }

      await tester.tap(find.text(TruckGroup.heavy.labelAr).last);
      await tester.pumpAndSettle();
      expect(selected, TruckGroup.heavy);
    });
  });

  group('TruckCategoryDropdown', () {
    testWidgets('uses initial value only when it matches an item', (tester) async {
      final categories =
          TruckClassificationCatalog.categoriesForGroup(TruckGroup.medium);

      String? selected = 'unknown';

      await tester.pumpWidget(
        buildTestApp(
          Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(24),
              child: TruckCategoryDropdown(
                categories: categories,
                value: selected,
                onChanged: (next) => selected = next,
              ),
            ),
          ),
        ),
      );

      final field = tester
          .widget<DropdownButtonFormField<String>>(find.byType(DropdownButtonFormField<String>));
      expect(field.initialValue, isNull);
    });

    testWidgets('disables onChanged when enabled is false', (tester) async {
      final categories =
          TruckClassificationCatalog.categoriesForGroup(TruckGroup.light);

      await tester.pumpWidget(
        buildTestApp(
          Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(24),
              child: TruckCategoryDropdown(
                categories: categories,
                value: categories.first.id,
                enabled: false,
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      );

      final field = tester
          .widget<DropdownButtonFormField<String>>(find.byType(DropdownButtonFormField<String>));
      expect(field.onChanged, isNull);
    });
  });

  group('TruckAxleDropdown', () {
    testWidgets('renders all axle options in Arabic', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(24),
              child: TruckAxleDropdown(
                axleCounts: const [2, 3, 4],
                value: null,
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(DropdownButtonFormField<int>));
      await tester.pumpAndSettle();

      expect(find.text('2 محور'), findsWidgets);
      expect(find.text('3 محور'), findsWidgets);
      expect(find.text('4 محور'), findsWidgets);
    });

    testWidgets('ignores selected value when not in options', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(24),
              child: TruckAxleDropdown(
                axleCounts: const [2, 3],
                value: 99,
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      );

      final field = tester
          .widget<DropdownButtonFormField<int>>(find.byType(DropdownButtonFormField<int>));
      expect(field.initialValue, isNull);
    });
  });

  group('TruckBodyTypeDropdown', () {
    testWidgets('renders body labels and accepts onChanged when enabled', (tester) async {
      const bodies = [
        TruckBodyType(id: 'box', labelAr: 'صندوق', labelEn: 'Box'),
        TruckBodyType(id: 'flat', labelAr: 'مسطحة', labelEn: 'Flat'),
      ];

      String? selected;
      await tester.pumpWidget(
        buildTestApp(
          Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(24),
              child: TruckBodyTypeDropdown(
                bodyTypes: bodies,
                value: 'box',
                onChanged: (v) => selected = v,
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();

      await tester.tap(find.text('مسطحة').last);
      await tester.pumpAndSettle();
      expect(selected, 'flat');
    });

    testWidgets('clears initial value when not present in body types', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(24),
              child: TruckBodyTypeDropdown(
                bodyTypes: const [
                  TruckBodyType(id: 'box', labelAr: 'صندوق', labelEn: 'Box'),
                ],
                value: 'unknown',
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      );

      final field = tester
          .widget<DropdownButtonFormField<String>>(find.byType(DropdownButtonFormField<String>));
      expect(field.initialValue, isNull);
    });
  });

  group('TruckCapacityDropdown', () {
    testWidgets('renders capacity labels and clears unknown values', (tester) async {
      const capacities = [
        TruckCapacity(
          id: 'small',
          labelAr: 'صغير',
          minTons: 1,
          maxTons: 3,
          defaultTons: 2,
        ),
        TruckCapacity(
          id: 'large',
          labelAr: 'كبير',
          minTons: 5,
          maxTons: 10,
          defaultTons: 7,
        ),
      ];

      await tester.pumpWidget(
        buildTestApp(
          Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(24),
              child: TruckCapacityDropdown(
                capacities: capacities,
                value: 'mystery',
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      );

      final field = tester
          .widget<DropdownButtonFormField<String>>(find.byType(DropdownButtonFormField<String>));
      expect(field.initialValue, isNull);

      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      expect(find.text('صغير'), findsWidgets);
      expect(find.text('كبير'), findsWidgets);
    });
  });
}
