const { getCategoryById, TRUCK_GROUPS } = require('../constants/truckClassification');

function normalizeGroup(value) {
  if (!value) return null;
  const text = String(value).trim();
  return Object.values(TRUCK_GROUPS).includes(text) ? text : null;
}

function buildTruckRequirementPayload(raw = {}, weightKg = null) {
  const category = raw.required_truck_category || raw.requiredTruckCategory || raw.category || null;
  const rawGroup = raw.required_truck_group || raw.requiredTruckGroup || raw.truckGroup || null;
  const group =
    normalizeGroup(rawGroup) ||
    getCategoryById(category)?.group ||
    null;

  let axleCount = raw.required_axle_count ?? raw.requiredAxleCount ?? raw.axle_count ?? raw.axleCount;
  if (axleCount != null && axleCount !== '') axleCount = Number(axleCount);
  else axleCount = null;

  const bodyType =
    raw.required_body_type || raw.requiredBodyType || raw.body_type || raw.bodyType || null;

  let minCapacityTons =
    raw.required_min_capacity_tons ??
    raw.requiredMinCapacityTons ??
    raw.max_weight_tons ??
    raw.maxWeightTons;
  if (minCapacityTons != null && minCapacityTons !== '') {
    minCapacityTons = Number(minCapacityTons);
  } else if (weightKg != null) {
    minCapacityTons = Number((Number(weightKg) / 1000).toFixed(2));
  } else {
    minCapacityTons = null;
  }

  if (category && !getCategoryById(category)) {
    return { ok: false, error: 'فئة الشاحنة المطلوبة غير معروفة' };
  }

  if (rawGroup && !normalizeGroup(rawGroup)) {
    return { ok: false, error: 'مجموعة الشاحنة المطلوبة غير صالحة' };
  }

  if (category) {
    const cat = getCategoryById(category);
    if (group && cat.group !== group) {
      return { ok: false, error: 'مجموعة الشاحنة لا تطابق الفئة المختارة' };
    }
    if (axleCount != null && !cat.axleCounts.includes(axleCount)) {
      return { ok: false, error: 'عدد المحاور غير متوافق مع فئة الشاحنة المطلوبة' };
    }
    if (bodyType && !cat.bodyTypes.includes(bodyType)) {
      return { ok: false, error: 'نوع الهيكل غير متوافق مع فئة الشاحنة المطلوبة' };
    }
  }

  return {
    ok: true,
    data: {
      required_truck_group: group,
      required_truck_category: category || null,
      required_axle_count: axleCount,
      required_body_type: bodyType || null,
      required_min_capacity_tons: minCapacityTons,
    },
  };
}

function truckMatchesShipment(activeTruck, shipment) {
  if (!activeTruck || !shipment) return false;

  const truckCapacityTons = Number(activeTruck.max_weight_tons || 0);
  const shipmentWeightTons = Number(shipment.weight_kg || 0) / 1000;
  const requiredMinTons = shipment.required_min_capacity_tons != null
    ? Number(shipment.required_min_capacity_tons)
    : shipmentWeightTons;

  if (truckCapacityTons > 0 && shipmentWeightTons > 0 && truckCapacityTons < shipmentWeightTons) {
    return false;
  }
  if (truckCapacityTons > 0 && requiredMinTons > 0 && truckCapacityTons < requiredMinTons) {
    return false;
  }

  if (shipment.required_truck_category) {
    if (activeTruck.category !== shipment.required_truck_category) return false;
  } else if (shipment.required_truck_group) {
    const truckCat = getCategoryById(activeTruck.category);
    if (!truckCat || truckCat.group !== shipment.required_truck_group) return false;
  }

  if (
    shipment.required_axle_count != null &&
    Number(activeTruck.axle_count) < Number(shipment.required_axle_count)
  ) {
    return false;
  }

  if (shipment.required_body_type && activeTruck.body_type !== shipment.required_body_type) {
    return false;
  }

  return true;
}

module.exports = {
  buildTruckRequirementPayload,
  truckMatchesShipment,
};
