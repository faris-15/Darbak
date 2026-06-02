import 'package:flutter_test/flutter_test.dart';
import 'package:darbak/truck_classification/truck_classification_models.dart';

void main() {
  group('TruckGroup labels and ids', () {
    test('exposes Arabic labels for every group', () {
      expect(TruckGroup.light.labelAr, 'شاحنات خفيفة');
      expect(TruckGroup.medium.labelAr, 'شاحنات متوسطة');
      expect(TruckGroup.heavy.labelAr, 'شاحنات ثقيلة');
      expect(TruckGroup.specialized.labelAr, 'شاحنات متخصصة');
    });

    test('exposes stable id strings', () {
      expect(TruckGroup.light.id, 'light');
      expect(TruckGroup.medium.id, 'medium');
      expect(TruckGroup.heavy.id, 'heavy');
      expect(TruckGroup.specialized.id, 'specialized');
    });

    test('round-trips through TruckGroupLabels.fromId', () {
      for (final g in TruckGroup.values) {
        expect(TruckGroupLabels.fromId(g.id), g);
      }
      expect(TruckGroupLabels.fromId(null), isNull);
      expect(TruckGroupLabels.fromId('unknown'), isNull);
    });
  });

  group('TruckBodyType / TruckCapacity / TruckAxleType', () {
    test('stores constructor values', () {
      const body = TruckBodyType(id: 'x', labelAr: 'هيكل', labelEn: 'Body');
      expect(body.id, 'x');
      expect(body.labelAr, 'هيكل');
      expect(body.labelEn, 'Body');

      const capacity = TruckCapacity(
        id: 'cap',
        labelAr: 'سعة',
        minTons: 1,
        maxTons: 5,
        defaultTons: 2.5,
      );
      expect(capacity.id, 'cap');
      expect(capacity.minTons, 1);
      expect(capacity.maxTons, 5);
      expect(capacity.defaultTons, 2.5);

      const axle = TruckAxleType(count: 3, labelAr: '٣ محاور');
      expect(axle.count, 3);
      expect(axle.labelAr, '٣ محاور');
    });
  });

  group('TruckConfiguration', () {
    test('builds the API payload, converting tons to capacity_kg', () {
      const config = TruckConfiguration(
        categoryId: 'heavy_triple_15_25',
        axleCount: 3,
        bodyTypeId: 'flatbed',
        payloadCapacityId: '20_25',
        maxWeightTons: 22.5,
        displayLabelAr: '٣ محاور · مسطحة · ٢٠–٢٥ طن',
      );

      expect(config.toApiPayload(), {
        'category': 'heavy_triple_15_25',
        'axle_count': 3,
        'body_type': 'flatbed',
        'payload_capacity': '20_25',
        'max_weight_tons': 22.5,
        'truck_type': '٣ محاور · مسطحة · ٢٠–٢٥ طن',
        'capacity_kg': 22500,
      });
    });

    test('hydrates from a classification map and top-level truck_type', () {
      final config = TruckConfiguration.fromJson({
        'classification': {
          'category': 'medium_double_5_10',
          'axle_count': '2',
          'body_type': 'box',
          'payload_capacity': '5_10',
          'max_weight_tons': '7.5',
        },
        'truck_type': 'محورين · صندوق · ٥–١٠ طن',
      });

      expect(config.categoryId, 'medium_double_5_10');
      expect(config.axleCount, 2);
      expect(config.bodyTypeId, 'box');
      expect(config.payloadCapacityId, '5_10');
      expect(config.maxWeightTons, 7.5);
      expect(config.displayLabelAr, 'محورين · صندوق · ٥–١٠ طن');
    });

    test('hydrates from flat fields when no classification map is provided', () {
      final config = TruckConfiguration.fromJson({
        'category': 'light_single_1_3',
        'axle_count': 1,
        'body_type': 'standard_cargo',
        'payload_capacity': '1_3',
        'max_weight_tons': 2.0,
        'truck_type': 'دباب',
      });

      expect(config.categoryId, 'light_single_1_3');
      expect(config.axleCount, 1);
      expect(config.maxWeightTons, 2);
      expect(config.displayLabelAr, 'دباب');
    });

    test('falls back to safe defaults for malformed payloads', () {
      final config = TruckConfiguration.fromJson({});

      expect(config.categoryId, '');
      expect(config.axleCount, 0);
      expect(config.bodyTypeId, '');
      expect(config.payloadCapacityId, '');
      expect(config.maxWeightTons, 0);
      expect(config.displayLabelAr, '');
    });

    test('rounds capacity_kg with floating-point precision', () {
      const config = TruckConfiguration(
        categoryId: 'c',
        axleCount: 2,
        bodyTypeId: 'box',
        payloadCapacityId: 'p',
        maxWeightTons: 12.345,
        displayLabelAr: 'd',
      );
      expect(config.toApiPayload()['capacity_kg'], 12345);
    });
  });
}
