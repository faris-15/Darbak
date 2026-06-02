import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:darbak/truck_classification/truck_classification_models.dart';
import 'package:darbak/truck_classification/widgets/truck_configuration_form.dart';
import 'package:darbak/truck_classification/widgets/truck_classification_dropdowns.dart';

import '../helpers/test_app.dart';

void main() {
  group('TruckConfigurationForm', () {
    testWidgets('renders header copy and group dropdown by default', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const Scaffold(
            body: Padding(
              padding: EdgeInsets.all(16),
              child: TruckConfigurationForm(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('تصنيف الشاحنة'), findsOneWidget);
      expect(
        find.text('اختر المجموعة ثم الفئة — تظهر الخيارات المتوافقة فقط'),
        findsOneWidget,
      );
      expect(find.byType(TruckGroupDropdown), findsOneWidget);
      expect(find.byType(TruckCategoryDropdown), findsOneWidget);
      expect(find.byType(TruckAxleDropdown), findsNothing);
      expect(find.byType(TruckBodyTypeDropdown), findsNothing);
      expect(find.byType(TruckCapacityDropdown), findsNothing);
    });

    testWidgets('reveals axle/body/capacity dropdowns once a category resolves', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const Scaffold(
            body: Padding(
              padding: EdgeInsets.all(16),
              child: TruckConfigurationForm(
                initialGroup: TruckGroup.medium,
                initialCategoryId: 'medium_double_5_10',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TruckAxleDropdown), findsOneWidget);
      expect(find.byType(TruckBodyTypeDropdown), findsOneWidget);
      expect(find.byType(TruckCapacityDropdown), findsOneWidget);
    });

    testWidgets('shows summary chip when configuration is fully resolved', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const Scaffold(
            body: Padding(
              padding: EdgeInsets.all(16),
              child: TruckConfigurationForm(
                initialGroup: TruckGroup.medium,
                initialCategoryId: 'medium_double_5_10',
                initialAxleCount: 2,
                initialBodyTypeId: 'box',
                initialCapacityId: '5_10',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
    });

    testWidgets('hides summary chip when showSummary is false', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const Scaffold(
            body: Padding(
              padding: EdgeInsets.all(16),
              child: TruckConfigurationForm(
                initialGroup: TruckGroup.medium,
                initialCategoryId: 'medium_double_5_10',
                initialAxleCount: 2,
                initialBodyTypeId: 'box',
                initialCapacityId: '5_10',
                showSummary: false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.check_circle_outline), findsNothing);
    });

    testWidgets('emits onChanged with the resolved configuration after initial frame', (tester) async {
      TruckConfiguration? captured = const TruckConfiguration(
        categoryId: '_initial_',
        axleCount: 0,
        bodyTypeId: '',
        payloadCapacityId: '',
        maxWeightTons: 0,
        displayLabelAr: '',
      );

      await tester.pumpWidget(
        buildTestApp(
          Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: TruckConfigurationForm(
                initialGroup: TruckGroup.medium,
                initialCategoryId: 'medium_double_5_10',
                initialAxleCount: 2,
                initialBodyTypeId: 'box',
                initialCapacityId: '5_10',
                onChanged: (config) => captured = config,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(captured, isNotNull);
      expect(captured!.categoryId, 'medium_double_5_10');
      expect(captured!.axleCount, 2);
    });

    testWidgets('selecting a category with single options auto-fills downstream fields', (tester) async {
      final formKey = GlobalKey<TruckConfigurationFormState>();
      var callbackInvocations = 0;
      TruckConfiguration? captured;

      await tester.pumpWidget(
        buildTestApp(
          Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: TruckConfigurationForm(
                key: formKey,
                initialGroup: TruckGroup.light,
                onChanged: (config) {
                  callbackInvocations++;
                  captured = config;
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(TruckCategoryDropdown));
      await tester.pumpAndSettle();
      await tester.tap(find.text('محور واحد — ١ إلى ٣ طن').last);
      await tester.pumpAndSettle();

      expect(callbackInvocations, greaterThan(1));
      expect(captured, isNull);
      expect(find.byType(TruckAxleDropdown), findsOneWidget);
      expect(find.byType(TruckBodyTypeDropdown), findsOneWidget);
      expect(find.byType(TruckCapacityDropdown), findsOneWidget);

      final state = formKey.currentState!;
      expect(state.validate(), 'اختر نوع الهيكل');
    });

    testWidgets('changing group clears the previous category selection', (tester) async {
      TruckConfiguration? captured;

      await tester.pumpWidget(
        buildTestApp(
          Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: TruckConfigurationForm(
                initialGroup: TruckGroup.medium,
                initialCategoryId: 'medium_double_5_10',
                initialAxleCount: 2,
                initialBodyTypeId: 'box',
                initialCapacityId: '5_10',
                onChanged: (config) => captured = config,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(captured, isNotNull);

      await tester.tap(find.byType(TruckGroupDropdown));
      await tester.pumpAndSettle();
      await tester.tap(find.text(TruckGroup.heavy.labelAr).last);
      await tester.pumpAndSettle();

      expect(captured, isNull);
      expect(find.byType(TruckAxleDropdown), findsNothing);
    });

    testWidgets('exposes a public validate() helper via GlobalKey', (tester) async {
      final formKey = GlobalKey<TruckConfigurationFormState>();

      await tester.pumpWidget(
        buildTestApp(
          Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: TruckConfigurationForm(key: formKey),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(formKey.currentState!.validate(), isNotNull);
      expect(formKey.currentState!.configuration, isNull);
      expect(formKey.currentState!.validateAll(), isFalse);
    });
  });
}
