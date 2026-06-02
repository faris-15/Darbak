/**
 * Covers two defensive branches in `utils/truckClassificationValidator.js`
 * that the real `constants/truckClassification.js` catalog cannot reach:
 *
 *   - line 79 — body_type listed in `category.bodyTypes` but missing from
 *     the global BODY_TYPES map (truly malformed catalog).
 *   - line 106 — `capacity` exists but its `defaultTons` is null/undefined,
 *     forcing the second fallback to `capacity.maxTons`.
 *
 * We mock the constants module per-test using `jest.isolateModules` so the
 * regular validator suite still binds to the real catalog.
 */
'use strict';

describe('validateTruckClassification — defensive fallbacks', () => {
  test('rejects body_type that is allow-listed by a category but missing from BODY_TYPES', () => {
    let validator;
    jest.isolateModules(() => {
      const TRUCK_CATEGORIES = [
        {
          id: 'cat_with_phantom_body',
          group: 'light',
          labelAr: 'تجريبي',
          labelEn: 'Test',
          axleCounts: [1],
          bodyTypes: ['phantom_body'],
          capacities: [
            {
              id: 'small',
              labelAr: 'صغير',
              minTons: 1,
              maxTons: 3,
              defaultTons: 2,
            },
          ],
          defaultBodyType: 'phantom_body',
        },
      ];
      const BODY_TYPES = {};
      jest.doMock('../../constants/truckClassification', () => ({
        TRUCK_CATEGORIES,
        BODY_TYPES,
        LEGACY_TRUCK_TYPE_MAP: {},
        getCategoryById: (id) =>
          id === 'cat_with_phantom_body' ? TRUCK_CATEGORIES[0] : null,
        getBodyTypeById: () => null,
        getCapacityForCategory: (catId, capId) =>
          catId === 'cat_with_phantom_body'
            ? TRUCK_CATEGORIES[0].capacities.find((c) => c.id === capId) || null
            : null,
        buildDisplayLabelAr: () => 'تجريبي',
      }));
      validator = require('../../utils/truckClassificationValidator');
    });

    const result = validator.validateTruckClassification({
      category: 'cat_with_phantom_body',
      axle_count: 1,
      body_type: 'phantom_body',
      payload_capacity: 'small',
      max_weight_tons: 2,
    });

    expect(result.ok).toBe(false);
    expect(result.errors).toContain('نوع الهيكل غير معروف');
  });

  test('falls back to capacity.maxTons when defaultTons is missing', () => {
    let validator;
    jest.isolateModules(() => {
      const TRUCK_CATEGORIES = [
        {
          id: 'cat_no_default_tons',
          group: 'light',
          labelAr: 'بدون افتراضي',
          labelEn: 'No-default',
          axleCounts: [1],
          bodyTypes: ['box'],
          capacities: [
            {
              id: 'mid',
              labelAr: 'متوسط',
              minTons: 5,
              maxTons: 10,
              // no defaultTons -> forces second fallback to maxTons
            },
          ],
          defaultBodyType: 'box',
        },
      ];
      const BODY_TYPES = {
        box: { id: 'box', labelAr: 'صندوق', labelEn: 'Box' },
      };
      jest.doMock('../../constants/truckClassification', () => ({
        TRUCK_CATEGORIES,
        BODY_TYPES,
        LEGACY_TRUCK_TYPE_MAP: {},
        getCategoryById: (id) =>
          id === 'cat_no_default_tons' ? TRUCK_CATEGORIES[0] : null,
        getBodyTypeById: (id) => BODY_TYPES[id] || null,
        getCapacityForCategory: (catId, capId) =>
          catId === 'cat_no_default_tons'
            ? TRUCK_CATEGORIES[0].capacities.find((c) => c.id === capId) || null
            : null,
        buildDisplayLabelAr: () => 'بدون افتراضي',
      }));
      validator = require('../../utils/truckClassificationValidator');
    });

    const result = validator.validateTruckClassification({
      category: 'cat_no_default_tons',
      axle_count: 1,
      body_type: 'box',
      payload_capacity: 'mid',
      // NO max_weight_tons -> defaults applied internally
    });

    expect(result.ok).toBe(true);
    expect(result.data.max_weight_tons).toBe(10);
    expect(result.data.capacity_kg).toBe(10000);
  });
});
