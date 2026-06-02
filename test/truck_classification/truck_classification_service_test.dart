import 'package:flutter_test/flutter_test.dart';
import 'package:darbak/truck_classification/truck_classification_catalog.dart';
import 'package:darbak/truck_classification/truck_classification_models.dart';
import 'package:darbak/truck_classification/truck_classification_service.dart';

void main() {
  const service = TruckClassificationService();

  group('TruckClassificationCatalog invariants', () {
    test('all category ids are unique and body type references resolve', () {
      final ids = TruckClassificationCatalog.categories.map((c) => c.id).toList();
      expect(ids.toSet(), hasLength(ids.length));

      for (final category in TruckClassificationCatalog.categories) {
        expect(category.axleCounts, isNotEmpty);
        expect(category.bodyTypeIds, contains(category.defaultBodyTypeId));
        expect(category.capacities, isNotEmpty);
        for (final bodyId in category.bodyTypeIds) {
          expect(TruckClassificationCatalog.bodyTypeById(bodyId), isNotNull);
        }
      }
    });
  });

  group('dependent dropdown service', () {
    test('filters categories by group', () {
      final medium = service.categoriesForGroup(TruckGroup.medium);
      expect(medium, isNotEmpty);
      expect(medium.every((c) => c.group == TruckGroup.medium), isTrue);
      expect(service.categoriesForGroup(null), isEmpty);
    });

    test('validates missing and mismatched selections', () {
      expect(service.validateSelection(), 'اختر مجموعة الشاحنة');
      expect(
        service.validateSelection(
          group: TruckGroup.light,
          categoryId: 'medium_double_5_10',
        ),
        'اختر فئة الشاحنة',
      );
      expect(
        service.validateSelection(
          group: TruckGroup.medium,
          categoryId: 'medium_double_5_10',
          axleCount: 99,
        ),
        'اختر عدد المحاور',
      );
    });

    test('resolves a valid API configuration', () {
      final config = service.resolveConfiguration(
        group: TruckGroup.medium,
        categoryId: 'medium_double_5_10',
        axleCount: 2,
        bodyTypeId: 'box',
        capacityId: '5_10',
      );

      expect(config, isNotNull);
      expect(config!.toApiPayload(), {
        'category': 'medium_double_5_10',
        'axle_count': 2,
        'body_type': 'box',
        'payload_capacity': '5_10',
        'max_weight_tons': 7.5,
        'truck_type': config.displayLabelAr,
        'capacity_kg': 7500,
      });
    });

    test('suggests category and group from cargo weight', () {
      expect(service.suggestCategoryIdForWeightTons(3), 'light_single_1_3');
      expect(service.suggestCategoryIdForWeightTons(5), 'light_single_3_5');
      expect(service.suggestCategoryIdForWeightTons(10), 'medium_double_5_10');
      expect(service.suggestCategoryIdForWeightTons(15), 'medium_double_10_15');
      expect(service.suggestCategoryIdForWeightTons(25), 'heavy_triple_15_25');
      expect(service.suggestGroupForWeightTons(7), TruckGroup.medium);
    });

    test('hydrates selection from modern and legacy truck rows', () {
      final modern = service.selectionFromTruckJson({
        'classification': {
          'category': 'medium_double_5_10',
          'axle_count': '2',
          'body_type': 'box',
          'payload_capacity': '5_10',
        },
      });
      expect(modern.group, TruckGroup.medium);
      expect(modern.axleCount, 2);

      final legacy = service.selectionFromTruckJson({'truck_type': 'دينا'});
      expect(legacy.group, TruckGroup.medium);
      expect(legacy.categoryId, 'medium_double_5_10');
      expect(legacy.bodyTypeId, 'box');
    });
  });
}
