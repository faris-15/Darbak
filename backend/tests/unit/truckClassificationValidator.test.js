/**
 * Tests for utils/truckClassificationValidator.js
 *
 * The validator is the single source of truth used at:
 *   - driver registration (controllers/authController.js#register)
 *   - truck creation / update (controllers/truckController.js)
 *   - registration form (Flutter calls /api/auth/register)
 *
 * We cover:
 *   - normalizeInput camelCase/snake_case + legacy mapping
 *   - happy-path validation
 *   - missing fields with `requireAll=true` vs `requireAll=false`
 *   - cross-field rejection (axle/body/capacity wrong for category)
 *   - max_weight_tons out of capacity bounds
 *   - capacity defaults applied when not given
 *   - the express middleware wrapper (sets req.truckClassification)
 *   - resolveTruckClassification short-circuits when middleware ran
 */
'use strict';

const {
  normalizeInput,
  validateTruckClassification,
  validateTruckClassificationMiddleware,
  resolveTruckClassification,
} = require('../../utils/truckClassificationValidator');

const valid = {
  category: 'medium_double_5_10',
  axle_count: 2,
  body_type: 'box',
  payload_capacity: '5_10',
  max_weight_tons: 7.5,
};

describe('normalizeInput', () => {
  test('returns undefined for missing fields', () => {
    expect(normalizeInput({})).toEqual({
      category: undefined,
      axle_count: undefined,
      body_type: undefined,
      payload_capacity: undefined,
      max_weight_tons: undefined,
      legacy_truck_type: null,
    });
  });

  test('accepts camelCase aliases', () => {
    expect(
      normalizeInput({
        category: 'medium_double_5_10',
        axleCount: '2',
        bodyType: 'box',
        payloadCapacity: '5_10',
        maxWeightTons: '7.5',
      })
    ).toMatchObject({
      category: 'medium_double_5_10',
      axle_count: 2,
      body_type: 'box',
      payload_capacity: '5_10',
      max_weight_tons: 7.5,
    });
  });

  test('expands a legacy Arabic truck type', () => {
    const out = normalizeInput({ truck_type: 'دينا' });
    expect(out).toMatchObject({
      category: 'medium_double_5_10',
      axle_count: 2,
      body_type: 'box',
      payload_capacity: '5_10',
      max_weight_tons: 7.5,
      legacy_truck_type: 'دينا',
    });
  });

  test('explicit fields override legacy mapping', () => {
    const out = normalizeInput({ truck_type: 'دينا', category: 'light_single_3_5' });
    expect(out.category).toBe('light_single_3_5');
  });
});

describe('validateTruckClassification', () => {
  test('happy path produces normalized data with display label and capacity_kg', () => {
    const result = validateTruckClassification(valid);
    expect(result.ok).toBe(true);
    expect(result.errors).toEqual([]);
    expect(result.data).toMatchObject({
      category: valid.category,
      axle_count: valid.axle_count,
      body_type: valid.body_type,
      payload_capacity: valid.payload_capacity,
      max_weight_tons: 7.5,
      capacity_kg: 7500,
    });
    expect(result.data.truck_type).toMatch(/محوران/);
    expect(result.data.classification_label_ar).toBe(result.data.truck_type);
  });

  test('with requireAll=false missing fields are not errors but ok=false (no category)', () => {
    const result = validateTruckClassification({}, { requireAll: false });
    expect(result.ok).toBe(false);
    expect(result.errors).toContain('فئة الشاحنة مطلوبة');
  });

  test('rejects unknown category', () => {
    const result = validateTruckClassification({ category: 'imaginary' });
    expect(result.ok).toBe(false);
    expect(result.errors).toContain('فئة الشاحنة غير معروفة');
  });

  test.each([
    ['axle count not allowed', { ...valid, axle_count: 5 }, /عدد المحاور/],
    ['body type not allowed',  { ...valid, body_type: 'lowbed' }, /نوع الهيكل/],
    ['payload capacity not allowed', { ...valid, payload_capacity: '40_60' }, /نطاق الحمولة/],
  ])('rejects when %s', (_l, payload, regex) => {
    const result = validateTruckClassification(payload);
    expect(result.ok).toBe(false);
    expect(result.errors.some((e) => regex.test(e))).toBe(true);
  });

  test('rejects max_weight_tons below the capacity minimum', () => {
    const result = validateTruckClassification({ ...valid, max_weight_tons: 1 });
    expect(result.ok).toBe(false);
    expect(result.errors[0]).toMatch(/الوزن الأقصى يجب أن يكون بين/);
  });

  test('rejects max_weight_tons above the capacity maximum', () => {
    const result = validateTruckClassification({ ...valid, max_weight_tons: 999 });
    expect(result.ok).toBe(false);
    expect(result.errors[0]).toMatch(/الوزن الأقصى يجب أن يكون بين/);
  });

  test('uses defaultTons when max_weight_tons omitted', () => {
    const { max_weight_tons, ...rest } = valid;
    const result = validateTruckClassification(rest);
    expect(result.ok).toBe(true);
    expect(result.data.max_weight_tons).toBe(7.5); // defaultTons of 5_10
  });

  test('treats empty string max_weight_tons as missing', () => {
    const result = validateTruckClassification({ ...valid, max_weight_tons: '' });
    expect(result.ok).toBe(true);
    expect(result.data.max_weight_tons).toBe(7.5);
  });

  test('reports "axle_count required" when category is valid but axle missing', () => {
    const result = validateTruckClassification({
      category: 'medium_double_5_10',
      body_type: 'box',
      payload_capacity: '5_10',
    });
    expect(result.ok).toBe(false);
    expect(result.errors).toContain('عدد المحاور مطلوب');
  });

  test('reports "body_type required" when category is valid but body_type missing', () => {
    const result = validateTruckClassification({
      category: 'medium_double_5_10',
      axle_count: 2,
      payload_capacity: '5_10',
    });
    expect(result.ok).toBe(false);
    expect(result.errors).toContain('نوع الهيكل مطلوب');
  });

  test('reports "payload_capacity required" when category is valid but capacity missing', () => {
    const result = validateTruckClassification({
      category: 'medium_double_5_10',
      axle_count: 2,
      body_type: 'box',
    });
    expect(result.ok).toBe(false);
    expect(result.errors).toContain('الحمولة القصوى مطلوبة');
  });

  test('with requireAll=false skips per-field "required" errors when category is valid', () => {
    const result = validateTruckClassification(
      { category: 'medium_double_5_10' },
      { requireAll: false },
    );
    // Without axle/body/capacity but requireAll=false, no "required"
    // errors are pushed and validation proceeds. The remaining capacity
    // lookup yields no maxTons, so the call still succeeds (ok=true).
    expect(result.ok).toBe(true);
    expect(result.data.category).toBe('medium_double_5_10');
  });
});

describe('validateTruckClassificationMiddleware', () => {
  const buildRes = () => ({
    statusCode: 200,
    body: null,
    status(code) { this.statusCode = code; return this; },
    json(payload) { this.body = payload; return this; },
  });

  test('400 with first error message when invalid', () => {
    const middleware = validateTruckClassificationMiddleware(true);
    const req = { body: { category: 'imaginary' } };
    const res = buildRes();
    const next = jest.fn();
    middleware(req, res, next);
    expect(res.statusCode).toBe(400);
    expect(res.body.message).toMatch(/فئة الشاحنة/);
    expect(next).not.toHaveBeenCalled();
  });

  test('attaches data and calls next() when valid', () => {
    const middleware = validateTruckClassificationMiddleware(true);
    const req = { body: { ...valid } };
    const res = buildRes();
    const next = jest.fn();
    middleware(req, res, next);
    expect(next).toHaveBeenCalledTimes(1);
    expect(req.truckClassification).toMatchObject({
      category: valid.category,
      capacity_kg: 7500,
    });
  });
});

describe('resolveTruckClassification', () => {
  test('returns the stashed payload if middleware already ran', () => {
    const req = { truckClassification: { category: 'medium_double_5_10' } };
    const result = resolveTruckClassification(req, {});
    expect(result.ok).toBe(true);
    expect(result.data.category).toBe('medium_double_5_10');
  });

  test('falls back to validating the body otherwise', () => {
    const req = {};
    const result = resolveTruckClassification(req, { ...valid });
    expect(result.ok).toBe(true);
    expect(result.data.capacity_kg).toBe(7500);
  });
});
