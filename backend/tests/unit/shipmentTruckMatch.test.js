/**
 * Tests for utils/shipmentTruckMatch.js — guarantees that:
 *   1. buildTruckRequirementPayload normalises camelCase / snake_case input,
 *      auto-derives the group from the category, and rejects mismatched
 *      combinations with localized error messages.
 *   2. truckMatchesShipment is *strict* about capacity, group, axle count,
 *      and body type so we never assign a shipment to an underspec'd truck.
 */
'use strict';

const {
  buildTruckRequirementPayload,
  truckMatchesShipment,
} = require('../../utils/shipmentTruckMatch');

describe('utils/shipmentTruckMatch.buildTruckRequirementPayload', () => {
  test('returns nulls when nothing is supplied', () => {
    const result = buildTruckRequirementPayload({});
    expect(result.ok).toBe(true);
    expect(result.data).toEqual({
      required_truck_group: null,
      required_truck_category: null,
      required_axle_count: null,
      required_body_type: null,
      required_min_capacity_tons: null,
    });
  });

  test('derives min capacity tons from weight_kg when not provided', () => {
    const result = buildTruckRequirementPayload({}, 7500);
    expect(result.data.required_min_capacity_tons).toBe(7.5);
  });

  test('explicit min capacity wins over weight_kg', () => {
    const result = buildTruckRequirementPayload(
      { required_min_capacity_tons: 12 },
      7500
    );
    expect(result.data.required_min_capacity_tons).toBe(12);
  });

  test('accepts both camelCase and snake_case keys', () => {
    const result = buildTruckRequirementPayload({
      requiredTruckCategory: 'medium_double_5_10',
      requiredAxleCount: 2,
      requiredBodyType: 'box',
      requiredMinCapacityTons: 8,
    });
    expect(result.ok).toBe(true);
    expect(result.data).toEqual({
      required_truck_group: 'medium',
      required_truck_category: 'medium_double_5_10',
      required_axle_count: 2,
      required_body_type: 'box',
      required_min_capacity_tons: 8,
    });
  });

  test('auto-fills group from a known category', () => {
    const result = buildTruckRequirementPayload({
      required_truck_category: 'heavy_flatbed_trailer_25_40',
    });
    expect(result.data.required_truck_group).toBe('heavy');
  });

  test('rejects unknown category', () => {
    const result = buildTruckRequirementPayload({ required_truck_category: 'xyz' });
    expect(result).toEqual({ ok: false, error: expect.stringMatching(/فئة الشاحنة/) });
  });

  test('rejects unknown group', () => {
    const result = buildTruckRequirementPayload({ required_truck_group: 'mega' });
    expect(result).toEqual({ ok: false, error: expect.stringMatching(/مجموعة الشاحنة/) });
  });

  test('rejects category whose group does not match supplied group', () => {
    const result = buildTruckRequirementPayload({
      required_truck_category: 'medium_double_5_10',
      required_truck_group: 'heavy',
    });
    expect(result).toEqual({ ok: false, error: expect.stringMatching(/لا تطابق/) });
  });

  test('rejects axle count not allowed for the category', () => {
    const result = buildTruckRequirementPayload({
      required_truck_category: 'medium_double_5_10',
      required_axle_count: 5,
    });
    expect(result).toEqual({ ok: false, error: expect.stringMatching(/عدد المحاور/) });
  });

  test('rejects body type not allowed for the category', () => {
    const result = buildTruckRequirementPayload({
      required_truck_category: 'medium_double_5_10',
      required_body_type: 'lowbed',
    });
    expect(result).toEqual({ ok: false, error: expect.stringMatching(/نوع الهيكل/) });
  });
});

describe('utils/shipmentTruckMatch.truckMatchesShipment', () => {
  const baseTruck = {
    category: 'medium_double_5_10',
    axle_count: 2,
    body_type: 'box',
    max_weight_tons: 8,
  };
  const baseShipment = {
    weight_kg: 5000, // 5 tons
    required_truck_category: 'medium_double_5_10',
    required_axle_count: 2,
    required_body_type: 'box',
    required_min_capacity_tons: 5,
  };

  test('matches the canonical case', () => {
    expect(truckMatchesShipment(baseTruck, baseShipment)).toBe(true);
  });

  test.each([
    ['null truck', null, baseShipment],
    ['null shipment', baseTruck, null],
  ])('returns false for %s', (_l, truck, shipment) => {
    expect(truckMatchesShipment(truck, shipment)).toBe(false);
  });

  test('rejects when truck capacity is below shipment weight', () => {
    expect(truckMatchesShipment({ ...baseTruck, max_weight_tons: 4 }, baseShipment)).toBe(false);
  });

  test('rejects when truck capacity is below required min', () => {
    expect(
      truckMatchesShipment({ ...baseTruck, max_weight_tons: 4 }, {
        ...baseShipment,
        weight_kg: 0,
        required_min_capacity_tons: 6,
      })
    ).toBe(false);
  });

  test('uses required_truck_group when category not specified', () => {
    expect(
      truckMatchesShipment(baseTruck, {
        ...baseShipment,
        required_truck_category: null,
        required_truck_group: 'medium',
      })
    ).toBe(true);
    expect(
      truckMatchesShipment(baseTruck, {
        ...baseShipment,
        required_truck_category: null,
        required_truck_group: 'heavy',
      })
    ).toBe(false);
  });

  test('rejects when category mismatches', () => {
    expect(
      truckMatchesShipment(baseTruck, {
        ...baseShipment,
        required_truck_category: 'heavy_flatbed_trailer_25_40',
      })
    ).toBe(false);
  });

  test('rejects when axle count is below requirement', () => {
    expect(
      truckMatchesShipment(
        { ...baseTruck, axle_count: 1 },
        { ...baseShipment, required_axle_count: 3 }
      )
    ).toBe(false);
  });

  test('rejects when body type mismatches', () => {
    expect(
      truckMatchesShipment(
        { ...baseTruck, body_type: 'flatbed' },
        baseShipment
      )
    ).toBe(false);
  });

  test('zero-or-missing capacities pass (legacy behaviour)', () => {
    expect(
      truckMatchesShipment(
        { ...baseTruck, max_weight_tons: 0 },
        { ...baseShipment, weight_kg: 0, required_min_capacity_tons: null }
      )
    ).toBe(true);
  });
});
