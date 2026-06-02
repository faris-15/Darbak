/**
 * Tests for constants/truckClassification.js — the central catalog used by
 * both backend validators and the Flutter dropdown.
 *
 * Catalog invariants we MUST hold (any failure is a contract break that
 * breaks driver registration / shipment matching):
 *   1. Every category has a unique id.
 *   2. Every category has at least one axleCount, bodyType and capacity.
 *   3. Every defaultBodyType is included in bodyTypes.
 *   4. Every body type referenced by a category exists in BODY_TYPES.
 *   5. Every capacity has 0 < minTons <= defaultTons <= maxTons.
 *   6. Every legacy mapping points to a valid (category, axle_count, body_type, payload_capacity).
 *   7. exportCatalog() returns enriched data shaped for the Flutter API.
 *
 * Plus targeted tests for the lookup helpers.
 */
'use strict';

const {
  TRUCK_GROUPS,
  BODY_TYPES,
  TRUCK_CATEGORIES,
  GROUP_LABELS,
  LEGACY_TRUCK_TYPE_MAP,
  getCategoryById,
  getBodyTypeById,
  getCapacityForCategory,
  buildDisplayLabelAr,
  exportCatalog,
} = require('../../constants/truckClassification');

describe('constants/truckClassification — catalog invariants', () => {
  test('all category ids are unique', () => {
    const ids = TRUCK_CATEGORIES.map((c) => c.id);
    expect(new Set(ids).size).toBe(ids.length);
  });

  test('every category has a known group, at least one axle, body type and capacity', () => {
    for (const cat of TRUCK_CATEGORIES) {
      expect(Object.values(TRUCK_GROUPS)).toContain(cat.group);
      expect(GROUP_LABELS[cat.group]).toBeDefined();
      expect(cat.axleCounts.length).toBeGreaterThan(0);
      expect(cat.bodyTypes.length).toBeGreaterThan(0);
      expect(cat.capacities.length).toBeGreaterThan(0);
    }
  });

  test('every category references existing body types and a valid default', () => {
    for (const cat of TRUCK_CATEGORIES) {
      for (const id of cat.bodyTypes) expect(BODY_TYPES[id]).toBeDefined();
      expect(cat.bodyTypes).toContain(cat.defaultBodyType);
    }
  });

  test('every capacity has 0 < min <= default <= max', () => {
    for (const cat of TRUCK_CATEGORIES) {
      for (const cap of cat.capacities) {
        expect(cap.minTons).toBeGreaterThan(0);
        expect(cap.maxTons).toBeGreaterThanOrEqual(cap.minTons);
        expect(cap.defaultTons).toBeGreaterThanOrEqual(cap.minTons);
        expect(cap.defaultTons).toBeLessThanOrEqual(cap.maxTons);
      }
    }
  });

  test('every legacy mapping resolves cleanly through the catalog', () => {
    for (const [legacyKey, mapping] of Object.entries(LEGACY_TRUCK_TYPE_MAP)) {
      const cat = getCategoryById(mapping.category);
      expect(cat).not.toBeNull();
      expect(cat.axleCounts).toContain(mapping.axle_count);
      expect(cat.bodyTypes).toContain(mapping.body_type);
      const cap = getCapacityForCategory(mapping.category, mapping.payload_capacity);
      expect(cap).not.toBeNull();
      expect(mapping.max_weight_tons).toBeGreaterThanOrEqual(cap.minTons);
      expect(mapping.max_weight_tons).toBeLessThanOrEqual(cap.maxTons);
    }
  });
});

describe('constants/truckClassification — helpers', () => {
  test('getCategoryById returns null for unknown ids', () => {
    expect(getCategoryById('does-not-exist')).toBeNull();
    expect(getCategoryById(null)).toBeNull();
    expect(getCategoryById('')).toBeNull();
  });

  test('getBodyTypeById returns the entry or null', () => {
    expect(getBodyTypeById('box')).toEqual(BODY_TYPES.box);
    expect(getBodyTypeById('mystery')).toBeNull();
  });

  test('getCapacityForCategory returns null for unknown category', () => {
    expect(getCapacityForCategory('xyz', '5_10')).toBeNull();
  });

  test('getCapacityForCategory returns null for unknown capacity in category', () => {
    expect(getCapacityForCategory('medium_double_5_10', 'never')).toBeNull();
  });

  test('buildDisplayLabelAr formats parts with the “·” separator', () => {
    const label = buildDisplayLabelAr({
      category: 'medium_double_5_10',
      axle_count: 2,
      body_type: 'box',
      payload_capacity: '5_10',
      max_weight_tons: 7.5,
    });
    expect(label).toContain('محوران');
    expect(label).toContain('صندوق مغلق');
    expect(label).toContain('٥–١٠ طن');
    expect(label).toContain('·');
  });

  test('buildDisplayLabelAr falls back to weight when capacity is unknown', () => {
    const label = buildDisplayLabelAr({
      category: 'medium_double_5_10',
      axle_count: 2,
      body_type: 'box',
      payload_capacity: 'unknown',
      max_weight_tons: 9.2,
    });
    expect(label).toContain('9.2 طن');
  });

  test('exportCatalog returns groups + bodyTypes + enriched categories', () => {
    const out = exportCatalog();
    expect(out.version).toBe(1);
    expect(out.groups).toEqual(
      expect.arrayContaining([
        expect.objectContaining({ id: 'light' }),
        expect.objectContaining({ id: 'medium' }),
        expect.objectContaining({ id: 'heavy' }),
        expect.objectContaining({ id: 'specialized' }),
      ])
    );
    expect(out.bodyTypes.find((b) => b.id === 'box')).toBeDefined();
    const medium = out.categories.find((c) => c.id === 'medium_double_5_10');
    expect(medium).toBeDefined();
    expect(medium.bodyTypeLabels[0]).toHaveProperty('labelAr');
    expect(medium.groupLabelAr).toBe(GROUP_LABELS.medium.ar);
  });
});
