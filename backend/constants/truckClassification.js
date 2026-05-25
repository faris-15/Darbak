/**
 * Central truck classification catalog for Saudi logistics operations.
 * IDs are stable API contract values — do not rename without a migration plan.
 */

const TRUCK_GROUPS = Object.freeze({
  LIGHT: 'light',
  MEDIUM: 'medium',
  HEAVY: 'heavy',
  SPECIALIZED: 'specialized',
});

const BODY_TYPES = Object.freeze({
  standard_cargo: { id: 'standard_cargo', labelAr: 'حمولة عامة', labelEn: 'Standard Cargo' },
  open_bed: { id: 'open_bed', labelAr: 'صندوق مفتوح', labelEn: 'Open Bed' },
  box: { id: 'box', labelAr: 'صندوق مغلق', labelEn: 'Box Body' },
  flatbed: { id: 'flatbed', labelAr: 'سطحة / مسطحة', labelEn: 'Flatbed' },
  curtain_side: { id: 'curtain_side', labelAr: 'ستارة جانبية', labelEn: 'Curtain Side' },
  refrigerated: { id: 'refrigerated', labelAr: 'مبرد', labelEn: 'Refrigerated' },
  dump: { id: 'dump', labelAr: 'قلاب', labelEn: 'Dump' },
  tanker: { id: 'tanker', labelAr: 'صهريج', labelEn: 'Tanker' },
  car_carrier: { id: 'car_carrier', labelAr: 'ناقلة سيارات', labelEn: 'Car Carrier' },
  recovery: { id: 'recovery', labelAr: 'سطحة / ونش', labelEn: 'Recovery / Winch' },
  lowbed: { id: 'lowbed', labelAr: 'لوبد / معدات ثقيلة', labelEn: 'Lowbed' },
  container: { id: 'container', labelAr: 'حاويات', labelEn: 'Container' },
  hazmat: { id: 'hazmat', labelAr: 'مواد خطرة', labelEn: 'Hazardous Materials' },
});

/** @type {import('./truckClassification.types').TruckCategorySpec[]} */
const TRUCK_CATEGORIES = [
  {
    id: 'light_single_1_3',
    group: TRUCK_GROUPS.LIGHT,
    labelAr: 'محور واحد — ١ إلى ٣ طن',
    labelEn: 'Single Axle — 1 to 3 tons',
    axleCounts: [1],
    bodyTypes: ['standard_cargo', 'open_bed'],
    capacities: [{ id: '1_3', labelAr: '١–٣ طن', minTons: 1, maxTons: 3, defaultTons: 2 }],
    defaultBodyType: 'standard_cargo',
  },
  {
    id: 'light_single_3_5',
    group: TRUCK_GROUPS.LIGHT,
    labelAr: 'محور واحد — ٣ إلى ٥ طن',
    labelEn: 'Single Axle — 3 to 5 tons',
    axleCounts: [1],
    bodyTypes: ['standard_cargo', 'open_bed', 'box'],
    capacities: [{ id: '3_5', labelAr: '٣–٥ طن', minTons: 3, maxTons: 5, defaultTons: 4 }],
    defaultBodyType: 'standard_cargo',
  },
  {
    id: 'medium_double_5_10',
    group: TRUCK_GROUPS.MEDIUM,
    labelAr: 'محوران — ٥ إلى ١٠ طن',
    labelEn: 'Double Axle — 5 to 10 tons',
    axleCounts: [2],
    bodyTypes: ['standard_cargo', 'box', 'open_bed'],
    capacities: [{ id: '5_10', labelAr: '٥–١٠ طن', minTons: 5, maxTons: 10, defaultTons: 7.5 }],
    defaultBodyType: 'box',
  },
  {
    id: 'medium_double_10_15',
    group: TRUCK_GROUPS.MEDIUM,
    labelAr: 'محوران — ١٠ إلى ١٥ طن',
    labelEn: 'Double Axle — 10 to 15 tons',
    axleCounts: [2],
    bodyTypes: ['standard_cargo', 'box', 'open_bed'],
    capacities: [{ id: '10_15', labelAr: '١٠–١٥ طن', minTons: 10, maxTons: 15, defaultTons: 12.5 }],
    defaultBodyType: 'box',
  },
  {
    id: 'heavy_triple_15_25',
    group: TRUCK_GROUPS.HEAVY,
    labelAr: '٣ محاور — ١٥ إلى ٢٥ طن',
    labelEn: '3 Axles — 15 to 25 tons',
    axleCounts: [3],
    bodyTypes: ['standard_cargo', 'box', 'flatbed'],
    capacities: [
      { id: '15_20', labelAr: '١٥–٢٠ طن', minTons: 15, maxTons: 20, defaultTons: 17.5 },
      { id: '20_25', labelAr: '٢٠–٢٥ طن', minTons: 20, maxTons: 25, defaultTons: 22.5 },
    ],
    defaultBodyType: 'standard_cargo',
  },
  {
    id: 'heavy_flatbed_trailer_25_40',
    group: TRUCK_GROUPS.HEAVY,
    labelAr: 'تريلا مسطحة — ٢٥ إلى ٤٠ طن',
    labelEn: 'Flatbed Trailer — 25 to 40 tons',
    axleCounts: [3, 4, 5],
    bodyTypes: ['flatbed'],
    capacities: [
      { id: '25_30', labelAr: '٢٥–٣٠ طن', minTons: 25, maxTons: 30, defaultTons: 27.5 },
      { id: '30_35', labelAr: '٣٠–٣٥ طن', minTons: 30, maxTons: 35, defaultTons: 32.5 },
      { id: '35_40', labelAr: '٣٥–٤٠ طن', minTons: 35, maxTons: 40, defaultTons: 37.5 },
    ],
    defaultBodyType: 'flatbed',
  },
  {
    id: 'heavy_curtain_trailer_25_40',
    group: TRUCK_GROUPS.HEAVY,
    labelAr: 'تريلا ستارة — ٢٥ إلى ٤٠ طن',
    labelEn: 'Curtain Trailer — 25 to 40 tons',
    axleCounts: [3, 4, 5],
    bodyTypes: ['curtain_side'],
    capacities: [
      { id: '25_30', labelAr: '٢٥–٣٠ طن', minTons: 25, maxTons: 30, defaultTons: 27.5 },
      { id: '30_35', labelAr: '٣٠–٣٥ طن', minTons: 30, maxTons: 35, defaultTons: 32.5 },
      { id: '35_40', labelAr: '٣٥–٤٠ طن', minTons: 35, maxTons: 40, defaultTons: 37.5 },
    ],
    defaultBodyType: 'curtain_side',
  },
  {
    id: 'heavy_reefer_trailer_20_35',
    group: TRUCK_GROUPS.HEAVY,
    labelAr: 'تريلا مبردة — ٢٠ إلى ٣٥ طن',
    labelEn: 'Refrigerated Trailer — 20 to 35 tons',
    axleCounts: [3, 4],
    bodyTypes: ['refrigerated'],
    capacities: [
      { id: '20_25', labelAr: '٢٠–٢٥ طن', minTons: 20, maxTons: 25, defaultTons: 22.5 },
      { id: '25_30', labelAr: '٢٥–٣٠ طن', minTons: 25, maxTons: 30, defaultTons: 27.5 },
      { id: '30_35', labelAr: '٣٠–٣٥ طن', minTons: 30, maxTons: 35, defaultTons: 32.5 },
    ],
    defaultBodyType: 'refrigerated',
  },
  {
    id: 'heavy_dump_20_40',
    group: TRUCK_GROUPS.HEAVY,
    labelAr: 'قلاب ثقيل — ٢٠ إلى ٤٠ طن',
    labelEn: 'Heavy Dump Truck — 20 to 40 tons',
    axleCounts: [3, 4],
    bodyTypes: ['dump'],
    capacities: [
      { id: '20_25', labelAr: '٢٠–٢٥ طن', minTons: 20, maxTons: 25, defaultTons: 22.5 },
      { id: '25_30', labelAr: '٢٥–٣٠ طن', minTons: 25, maxTons: 30, defaultTons: 27.5 },
      { id: '30_40', labelAr: '٣٠–٤٠ طن', minTons: 30, maxTons: 40, defaultTons: 35 },
    ],
    defaultBodyType: 'dump',
  },
  {
    id: 'heavy_tanker_variable',
    group: TRUCK_GROUPS.HEAVY,
    labelAr: 'صهريج — سعة متغيرة',
    labelEn: 'Tanker — variable capacity',
    axleCounts: [2, 3, 4],
    bodyTypes: ['tanker'],
    capacities: [
      { id: '10_20', labelAr: '١٠–٢٠ طن', minTons: 10, maxTons: 20, defaultTons: 15 },
      { id: '20_30', labelAr: '٢٠–٣٠ طن', minTons: 20, maxTons: 30, defaultTons: 25 },
      { id: '30_40', labelAr: '٣٠–٤٠ طن', minTons: 30, maxTons: 40, defaultTons: 35 },
    ],
    defaultBodyType: 'tanker',
  },
  {
    id: 'spec_car_carrier',
    group: TRUCK_GROUPS.SPECIALIZED,
    labelAr: 'ناقلة سيارات',
    labelEn: 'Car Carrier',
    axleCounts: [2, 3],
    bodyTypes: ['car_carrier'],
    capacities: [{ id: 'var_8_12', labelAr: '٨–١٢ طن', minTons: 8, maxTons: 12, defaultTons: 10 }],
    defaultBodyType: 'car_carrier',
  },
  {
    id: 'spec_recovery_winch',
    group: TRUCK_GROUPS.SPECIALIZED,
    labelAr: 'سطحة / ونش',
    labelEn: 'Recovery / Winch',
    axleCounts: [1, 2],
    bodyTypes: ['recovery'],
    capacities: [{ id: 'var_3_8', labelAr: '٣–٨ طن', minTons: 3, maxTons: 8, defaultTons: 5 }],
    defaultBodyType: 'recovery',
  },
  {
    id: 'spec_heavy_equipment',
    group: TRUCK_GROUPS.SPECIALIZED,
    labelAr: 'نقل معدات ثقيلة',
    labelEn: 'Heavy Equipment Transport',
    axleCounts: [3, 4, 5, 6],
    bodyTypes: ['lowbed'],
    capacities: [
      { id: '40_60', labelAr: '٤٠–٦٠ طن', minTons: 40, maxTons: 60, defaultTons: 50 },
      { id: '60_80', labelAr: '٦٠–٨٠ طن', minTons: 60, maxTons: 80, defaultTons: 70 },
    ],
    defaultBodyType: 'lowbed',
  },
  {
    id: 'spec_container',
    group: TRUCK_GROUPS.SPECIALIZED,
    labelAr: 'نقل حاويات',
    labelEn: 'Container Transport',
    axleCounts: [3, 4, 5],
    bodyTypes: ['container'],
    capacities: [
      { id: '25_30', labelAr: '٢٥–٣٠ طن', minTons: 25, maxTons: 30, defaultTons: 27.5 },
      { id: '30_40', labelAr: '٣٠–٤٠ طن', minTons: 30, maxTons: 40, defaultTons: 35 },
    ],
    defaultBodyType: 'container',
  },
  {
    id: 'spec_hazmat',
    group: TRUCK_GROUPS.SPECIALIZED,
    labelAr: 'نقل مواد خطرة',
    labelEn: 'Hazardous Materials Transport',
    axleCounts: [2, 3],
    bodyTypes: ['hazmat', 'tanker'],
    capacities: [
      { id: '10_20', labelAr: '١٠–٢٠ طن', minTons: 10, maxTons: 20, defaultTons: 15 },
      { id: '20_30', labelAr: '٢٠–٣٠ طن', minTons: 20, maxTons: 30, defaultTons: 25 },
    ],
    defaultBodyType: 'hazmat',
  },
];

const GROUP_LABELS = Object.freeze({
  [TRUCK_GROUPS.LIGHT]: { ar: 'شاحنات خفيفة', en: 'Light Trucks' },
  [TRUCK_GROUPS.MEDIUM]: { ar: 'شاحنات متوسطة', en: 'Medium Trucks' },
  [TRUCK_GROUPS.HEAVY]: { ar: 'شاحنات ثقيلة', en: 'Heavy Trucks' },
  [TRUCK_GROUPS.SPECIALIZED]: { ar: 'شاحنات متخصصة', en: 'Specialized Trucks' },
});

/** Maps legacy Arabic enum values to new classification IDs */
const LEGACY_TRUCK_TYPE_MAP = Object.freeze({
  'دباب نقل': {
    category: 'light_single_1_3',
    axle_count: 1,
    body_type: 'standard_cargo',
    payload_capacity: '1_3',
    max_weight_tons: 2,
  },
  'وانيت': {
    category: 'light_single_3_5',
    axle_count: 1,
    body_type: 'open_bed',
    payload_capacity: '3_5',
    max_weight_tons: 4,
  },
  دينا: {
    category: 'medium_double_5_10',
    axle_count: 2,
    body_type: 'box',
    payload_capacity: '5_10',
    max_weight_tons: 7.5,
  },
  لوري: {
    category: 'medium_double_10_15',
    axle_count: 2,
    body_type: 'box',
    payload_capacity: '10_15',
    max_weight_tons: 12.5,
  },
  سطحة: {
    category: 'spec_car_carrier',
    axle_count: 2,
    body_type: 'car_carrier',
    payload_capacity: 'var_8_12',
    max_weight_tons: 10,
  },
  'تريلا جوانب': {
    category: 'heavy_flatbed_trailer_25_40',
    axle_count: 3,
    body_type: 'flatbed',
    payload_capacity: '30_35',
    max_weight_tons: 32.5,
  },
  'تريلا ستارة': {
    category: 'heavy_curtain_trailer_25_40',
    axle_count: 3,
    body_type: 'curtain_side',
    payload_capacity: '30_35',
    max_weight_tons: 32.5,
  },
  برادة: {
    category: 'heavy_reefer_trailer_20_35',
    axle_count: 3,
    body_type: 'refrigerated',
    payload_capacity: '25_30',
    max_weight_tons: 27.5,
  },
  صهريج: {
    category: 'heavy_tanker_variable',
    axle_count: 3,
    body_type: 'tanker',
    payload_capacity: '20_30',
    max_weight_tons: 25,
  },
  قلاب: {
    category: 'heavy_dump_20_40',
    axle_count: 3,
    body_type: 'dump',
    payload_capacity: '25_30',
    max_weight_tons: 27.5,
  },
  مبرد: {
    category: 'heavy_reefer_trailer_20_35',
    axle_count: 3,
    body_type: 'refrigerated',
    payload_capacity: '20_25',
    max_weight_tons: 22.5,
  },
});

const categoryById = new Map(TRUCK_CATEGORIES.map((c) => [c.id, c]));

function getCategoryById(categoryId) {
  return categoryById.get(categoryId) || null;
}

function getBodyTypeById(bodyTypeId) {
  return BODY_TYPES[bodyTypeId] || null;
}

function getCapacityForCategory(categoryId, payloadCapacityId) {
  const category = getCategoryById(categoryId);
  if (!category) return null;
  return category.capacities.find((c) => c.id === payloadCapacityId) || null;
}

function buildDisplayLabelAr({ category, axle_count, body_type, payload_capacity, max_weight_tons }) {
  const cat = getCategoryById(category);
  const body = getBodyTypeById(body_type);
  const cap = getCapacityForCategory(category, payload_capacity);
  const parts = [];
  if (cat) parts.push(cat.labelAr);
  if (axle_count) parts.push(`${axle_count} محور`);
  if (body) parts.push(body.labelAr);
  if (cap) parts.push(cap.labelAr);
  else if (max_weight_tons) parts.push(`${max_weight_tons} طن`);
  return parts.join(' · ') || category || '';
}

function exportCatalog() {
  return {
    version: 1,
    groups: Object.values(TRUCK_GROUPS).map((id) => ({
      id,
      labelAr: GROUP_LABELS[id].ar,
      labelEn: GROUP_LABELS[id].en,
    })),
    bodyTypes: Object.values(BODY_TYPES),
    categories: TRUCK_CATEGORIES.map((cat) => ({
      ...cat,
      groupLabelAr: GROUP_LABELS[cat.group].ar,
      groupLabelEn: GROUP_LABELS[cat.group].en,
      bodyTypeLabels: cat.bodyTypes.map((id) => BODY_TYPES[id]),
    })),
  };
}

module.exports = {
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
};
