const {
  getCategoryById,
  getBodyTypeById,
  getCapacityForCategory,
  buildDisplayLabelAr,
  LEGACY_TRUCK_TYPE_MAP,
} = require('../constants/truckClassification');

function pickFirst(obj, keys) {
  for (const key of keys) {
    if (obj[key] !== undefined && obj[key] !== null && obj[key] !== '') {
      return obj[key];
    }
  }
  return undefined;
}

function normalizeInput(raw = {}) {
  const legacyType = pickFirst(raw, ['truck_type', 'truckType']);
  const legacyMapped =
    legacyType && LEGACY_TRUCK_TYPE_MAP[legacyType.trim()]
      ? LEGACY_TRUCK_TYPE_MAP[legacyType.trim()]
      : null;

  const category = pickFirst(raw, ['category']) ?? legacyMapped?.category;
  const axle_count = Number(
    pickFirst(raw, ['axle_count', 'axleCount']) ?? legacyMapped?.axle_count
  );
  const body_type = pickFirst(raw, ['body_type', 'bodyType']) ?? legacyMapped?.body_type;
  const payload_capacity =
    pickFirst(raw, ['payload_capacity', 'payloadCapacity']) ??
    legacyMapped?.payload_capacity;
  let max_weight_tons = pickFirst(raw, ['max_weight_tons', 'maxWeightTons']);
  if (max_weight_tons !== undefined && max_weight_tons !== null && max_weight_tons !== '') {
    max_weight_tons = Number(max_weight_tons);
  } else if (legacyMapped?.max_weight_tons != null) {
    max_weight_tons = legacyMapped.max_weight_tons;
  } else {
    max_weight_tons = undefined;
  }

  return {
    category,
    axle_count: Number.isFinite(axle_count) ? axle_count : undefined,
    body_type,
    payload_capacity,
    max_weight_tons: Number.isFinite(max_weight_tons) ? max_weight_tons : undefined,
    legacy_truck_type: legacyType?.trim() || null,
  };
}

/**
 * Validates truck classification and returns normalized payload for DB/API.
 * @returns {{ ok: boolean, errors: string[], data?: object }}
 */
function validateTruckClassification(raw = {}, { requireAll = true } = {}) {
  const input = normalizeInput(raw);
  const errors = [];

  if (!input.category) {
    if (requireAll) errors.push('فئة الشاحنة مطلوبة');
  } else if (!getCategoryById(input.category)) {
    errors.push('فئة الشاحنة غير معروفة');
  }

  const category = getCategoryById(input.category);
  if (category) {
    if (input.axle_count == null) {
      if (requireAll) errors.push('عدد المحاور مطلوب');
    } else if (!category.axleCounts.includes(input.axle_count)) {
      errors.push('عدد المحاور غير متوافق مع فئة الشاحنة');
    }

    if (!input.body_type) {
      if (requireAll) errors.push('نوع الهيكل مطلوب');
    } else if (!category.bodyTypes.includes(input.body_type)) {
      errors.push('نوع الهيكل غير متوافق مع فئة الشاحنة');
    } else if (!getBodyTypeById(input.body_type)) {
      errors.push('نوع الهيكل غير معروف');
    }

    if (!input.payload_capacity) {
      if (requireAll) errors.push('الحمولة القصوى مطلوبة');
    } else {
      const cap = getCapacityForCategory(input.category, input.payload_capacity);
      if (!cap) {
        errors.push('نطاق الحمولة غير متوافق مع فئة الشاحنة');
      }
    }
  }

  if (errors.length) {
    return { ok: false, errors };
  }

  if (!category) {
    return { ok: false, errors: ['فئة الشاحنة مطلوبة'] };
  }

  const capacity = getCapacityForCategory(input.category, input.payload_capacity);
  let maxTons = input.max_weight_tons;
  if (maxTons == null && capacity) {
    maxTons = capacity.defaultTons;
  }
  if (maxTons == null && capacity) {
    maxTons = capacity.maxTons;
  }
  if (capacity && maxTons != null) {
    if (maxTons < capacity.minTons || maxTons > capacity.maxTons) {
      errors.push(
        `الوزن الأقصى يجب أن يكون بين ${capacity.minTons} و ${capacity.maxTons} طن`
      );
    }
  }

  if (errors.length) {
    return { ok: false, errors };
  }

  const displayLabel = buildDisplayLabelAr({
    category: input.category,
    axle_count: input.axle_count,
    body_type: input.body_type,
    payload_capacity: input.payload_capacity,
    max_weight_tons: maxTons,
  });

  const capacityKg = maxTons != null ? Math.round(maxTons * 1000) : 0;

  return {
    ok: true,
    errors: [],
    data: {
      category: input.category,
      axle_count: input.axle_count,
      body_type: input.body_type,
      payload_capacity: input.payload_capacity,
      max_weight_tons: maxTons,
      capacity_kg: capacityKg,
      truck_type: displayLabel,
      classification_label_ar: displayLabel,
    },
  };
}

function validateTruckClassificationMiddleware(requireAll = true) {
  return (req, res, next) => {
    const result = validateTruckClassification(req.body, { requireAll });
    if (!result.ok) {
      return res.status(400).json({
        message: result.errors[0] || 'بيانات تصنيف الشاحنة غير صالحة',
        errors: result.errors,
      });
    }
    req.truckClassification = result.data;
    next();
  };
}

/** Use after middleware or run validation on body when middleware was skipped. */
function resolveTruckClassification(req, body, options = { requireAll: true }) {
  if (req.truckClassification) {
    return { ok: true, data: req.truckClassification, errors: [] };
  }
  return validateTruckClassification(body, options);
}

module.exports = {
  normalizeInput,
  validateTruckClassification,
  validateTruckClassificationMiddleware,
  resolveTruckClassification,
};
