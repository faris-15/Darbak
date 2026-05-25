import 'truck_classification_models.dart';

/// Single source of truth for truck taxonomy in the Flutter app (mirrors backend catalog IDs).
class TruckClassificationCatalog {
  TruckClassificationCatalog._();

  static const Map<String, TruckBodyType> bodyTypes = {
    'standard_cargo': TruckBodyType(
      id: 'standard_cargo',
      labelAr: 'حمولة عامة',
      labelEn: 'Standard Cargo',
    ),
    'open_bed': TruckBodyType(
      id: 'open_bed',
      labelAr: 'صندوق مفتوح',
      labelEn: 'Open Bed',
    ),
    'box': TruckBodyType(
      id: 'box',
      labelAr: 'صندوق مغلق',
      labelEn: 'Box Body',
    ),
    'flatbed': TruckBodyType(
      id: 'flatbed',
      labelAr: 'سطحة / مسطحة',
      labelEn: 'Flatbed',
    ),
    'curtain_side': TruckBodyType(
      id: 'curtain_side',
      labelAr: 'ستارة جانبية',
      labelEn: 'Curtain Side',
    ),
    'refrigerated': TruckBodyType(
      id: 'refrigerated',
      labelAr: 'مبرد',
      labelEn: 'Refrigerated',
    ),
    'dump': TruckBodyType(
      id: 'dump',
      labelAr: 'قلاب',
      labelEn: 'Dump',
    ),
    'tanker': TruckBodyType(
      id: 'tanker',
      labelAr: 'صهريج',
      labelEn: 'Tanker',
    ),
    'car_carrier': TruckBodyType(
      id: 'car_carrier',
      labelAr: 'ناقلة سيارات',
      labelEn: 'Car Carrier',
    ),
    'recovery': TruckBodyType(
      id: 'recovery',
      labelAr: 'سطحة / ونش',
      labelEn: 'Recovery / Winch',
    ),
    'lowbed': TruckBodyType(
      id: 'lowbed',
      labelAr: 'لوبد / معدات ثقيلة',
      labelEn: 'Lowbed',
    ),
    'container': TruckBodyType(
      id: 'container',
      labelAr: 'حاويات',
      labelEn: 'Container',
    ),
    'hazmat': TruckBodyType(
      id: 'hazmat',
      labelAr: 'مواد خطرة',
      labelEn: 'Hazardous Materials',
    ),
  };

  static final List<TruckCategory> categories = [
    TruckCategory(
      id: 'light_single_1_3',
      group: TruckGroup.light,
      labelAr: 'محور واحد — ١ إلى ٣ طن',
      labelEn: 'Single Axle — 1 to 3 tons',
      axleCounts: [1],
      bodyTypeIds: ['standard_cargo', 'open_bed'],
      capacities: const [
        TruckCapacity(
          id: '1_3',
          labelAr: '١–٣ طن',
          minTons: 1,
          maxTons: 3,
          defaultTons: 2,
        ),
      ],
      defaultBodyTypeId: 'standard_cargo',
    ),
    TruckCategory(
      id: 'light_single_3_5',
      group: TruckGroup.light,
      labelAr: 'محور واحد — ٣ إلى ٥ طن',
      labelEn: 'Single Axle — 3 to 5 tons',
      axleCounts: [1],
      bodyTypeIds: ['standard_cargo', 'open_bed', 'box'],
      capacities: const [
        TruckCapacity(
          id: '3_5',
          labelAr: '٣–٥ طن',
          minTons: 3,
          maxTons: 5,
          defaultTons: 4,
        ),
      ],
      defaultBodyTypeId: 'standard_cargo',
    ),
    TruckCategory(
      id: 'medium_double_5_10',
      group: TruckGroup.medium,
      labelAr: 'محوران — ٥ إلى ١٠ طن',
      labelEn: 'Double Axle — 5 to 10 tons',
      axleCounts: [2],
      bodyTypeIds: ['standard_cargo', 'box', 'open_bed'],
      capacities: const [
        TruckCapacity(
          id: '5_10',
          labelAr: '٥–١٠ طن',
          minTons: 5,
          maxTons: 10,
          defaultTons: 7.5,
        ),
      ],
      defaultBodyTypeId: 'box',
    ),
    TruckCategory(
      id: 'medium_double_10_15',
      group: TruckGroup.medium,
      labelAr: 'محوران — ١٠ إلى ١٥ طن',
      labelEn: 'Double Axle — 10 to 15 tons',
      axleCounts: [2],
      bodyTypeIds: ['standard_cargo', 'box', 'open_bed'],
      capacities: const [
        TruckCapacity(
          id: '10_15',
          labelAr: '١٠–١٥ طن',
          minTons: 10,
          maxTons: 15,
          defaultTons: 12.5,
        ),
      ],
      defaultBodyTypeId: 'box',
    ),
    TruckCategory(
      id: 'heavy_triple_15_25',
      group: TruckGroup.heavy,
      labelAr: '٣ محاور — ١٥ إلى ٢٥ طن',
      labelEn: '3 Axles — 15 to 25 tons',
      axleCounts: [3],
      bodyTypeIds: ['standard_cargo', 'box', 'flatbed'],
      capacities: const [
        TruckCapacity(
          id: '15_20',
          labelAr: '١٥–٢٠ طن',
          minTons: 15,
          maxTons: 20,
          defaultTons: 17.5,
        ),
        TruckCapacity(
          id: '20_25',
          labelAr: '٢٠–٢٥ طن',
          minTons: 20,
          maxTons: 25,
          defaultTons: 22.5,
        ),
      ],
      defaultBodyTypeId: 'standard_cargo',
    ),
    TruckCategory(
      id: 'heavy_flatbed_trailer_25_40',
      group: TruckGroup.heavy,
      labelAr: 'تريلا مسطحة — ٢٥ إلى ٤٠ طن',
      labelEn: 'Flatbed Trailer — 25 to 40 tons',
      axleCounts: [3, 4, 5],
      bodyTypeIds: ['flatbed'],
      capacities: const [
        TruckCapacity(
          id: '25_30',
          labelAr: '٢٥–٣٠ طن',
          minTons: 25,
          maxTons: 30,
          defaultTons: 27.5,
        ),
        TruckCapacity(
          id: '30_35',
          labelAr: '٣٠–٣٥ طن',
          minTons: 30,
          maxTons: 35,
          defaultTons: 32.5,
        ),
        TruckCapacity(
          id: '35_40',
          labelAr: '٣٥–٤٠ طن',
          minTons: 35,
          maxTons: 40,
          defaultTons: 37.5,
        ),
      ],
      defaultBodyTypeId: 'flatbed',
    ),
    TruckCategory(
      id: 'heavy_curtain_trailer_25_40',
      group: TruckGroup.heavy,
      labelAr: 'تريلا ستارة — ٢٥ إلى ٤٠ طن',
      labelEn: 'Curtain Trailer — 25 to 40 tons',
      axleCounts: [3, 4, 5],
      bodyTypeIds: ['curtain_side'],
      capacities: const [
        TruckCapacity(
          id: '25_30',
          labelAr: '٢٥–٣٠ طن',
          minTons: 25,
          maxTons: 30,
          defaultTons: 27.5,
        ),
        TruckCapacity(
          id: '30_35',
          labelAr: '٣٠–٣٥ طن',
          minTons: 30,
          maxTons: 35,
          defaultTons: 32.5,
        ),
        TruckCapacity(
          id: '35_40',
          labelAr: '٣٥–٤٠ طن',
          minTons: 35,
          maxTons: 40,
          defaultTons: 37.5,
        ),
      ],
      defaultBodyTypeId: 'curtain_side',
    ),
    TruckCategory(
      id: 'heavy_reefer_trailer_20_35',
      group: TruckGroup.heavy,
      labelAr: 'تريلا مبردة — ٢٠ إلى ٣٥ طن',
      labelEn: 'Refrigerated Trailer — 20 to 35 tons',
      axleCounts: [3, 4],
      bodyTypeIds: ['refrigerated'],
      capacities: const [
        TruckCapacity(
          id: '20_25',
          labelAr: '٢٠–٢٥ طن',
          minTons: 20,
          maxTons: 25,
          defaultTons: 22.5,
        ),
        TruckCapacity(
          id: '25_30',
          labelAr: '٢٥–٣٠ طن',
          minTons: 25,
          maxTons: 30,
          defaultTons: 27.5,
        ),
        TruckCapacity(
          id: '30_35',
          labelAr: '٣٠–٣٥ طن',
          minTons: 30,
          maxTons: 35,
          defaultTons: 32.5,
        ),
      ],
      defaultBodyTypeId: 'refrigerated',
    ),
    TruckCategory(
      id: 'heavy_dump_20_40',
      group: TruckGroup.heavy,
      labelAr: 'قلاب ثقيل — ٢٠ إلى ٤٠ طن',
      labelEn: 'Heavy Dump Truck — 20 to 40 tons',
      axleCounts: [3, 4],
      bodyTypeIds: ['dump'],
      capacities: const [
        TruckCapacity(
          id: '20_25',
          labelAr: '٢٠–٢٥ طن',
          minTons: 20,
          maxTons: 25,
          defaultTons: 22.5,
        ),
        TruckCapacity(
          id: '25_30',
          labelAr: '٢٥–٣٠ طن',
          minTons: 25,
          maxTons: 30,
          defaultTons: 27.5,
        ),
        TruckCapacity(
          id: '30_40',
          labelAr: '٣٠–٤٠ طن',
          minTons: 30,
          maxTons: 40,
          defaultTons: 35,
        ),
      ],
      defaultBodyTypeId: 'dump',
    ),
    TruckCategory(
      id: 'heavy_tanker_variable',
      group: TruckGroup.heavy,
      labelAr: 'صهريج — سعة متغيرة',
      labelEn: 'Tanker — variable capacity',
      axleCounts: [2, 3, 4],
      bodyTypeIds: ['tanker'],
      capacities: const [
        TruckCapacity(
          id: '10_20',
          labelAr: '١٠–٢٠ طن',
          minTons: 10,
          maxTons: 20,
          defaultTons: 15,
        ),
        TruckCapacity(
          id: '20_30',
          labelAr: '٢٠–٣٠ طن',
          minTons: 20,
          maxTons: 30,
          defaultTons: 25,
        ),
        TruckCapacity(
          id: '30_40',
          labelAr: '٣٠–٤٠ طن',
          minTons: 30,
          maxTons: 40,
          defaultTons: 35,
        ),
      ],
      defaultBodyTypeId: 'tanker',
    ),
    TruckCategory(
      id: 'spec_car_carrier',
      group: TruckGroup.specialized,
      labelAr: 'ناقلة سيارات',
      labelEn: 'Car Carrier',
      axleCounts: [2, 3],
      bodyTypeIds: ['car_carrier'],
      capacities: const [
        TruckCapacity(
          id: 'var_8_12',
          labelAr: '٨–١٢ طن',
          minTons: 8,
          maxTons: 12,
          defaultTons: 10,
        ),
      ],
      defaultBodyTypeId: 'car_carrier',
    ),
    TruckCategory(
      id: 'spec_recovery_winch',
      group: TruckGroup.specialized,
      labelAr: 'سطحة / ونش',
      labelEn: 'Recovery / Winch',
      axleCounts: [1, 2],
      bodyTypeIds: ['recovery'],
      capacities: const [
        TruckCapacity(
          id: 'var_3_8',
          labelAr: '٣–٨ طن',
          minTons: 3,
          maxTons: 8,
          defaultTons: 5,
        ),
      ],
      defaultBodyTypeId: 'recovery',
    ),
    TruckCategory(
      id: 'spec_heavy_equipment',
      group: TruckGroup.specialized,
      labelAr: 'نقل معدات ثقيلة',
      labelEn: 'Heavy Equipment Transport',
      axleCounts: [3, 4, 5, 6],
      bodyTypeIds: ['lowbed'],
      capacities: const [
        TruckCapacity(
          id: '40_60',
          labelAr: '٤٠–٦٠ طن',
          minTons: 40,
          maxTons: 60,
          defaultTons: 50,
        ),
        TruckCapacity(
          id: '60_80',
          labelAr: '٦٠–٨٠ طن',
          minTons: 60,
          maxTons: 80,
          defaultTons: 70,
        ),
      ],
      defaultBodyTypeId: 'lowbed',
    ),
    TruckCategory(
      id: 'spec_container',
      group: TruckGroup.specialized,
      labelAr: 'نقل حاويات',
      labelEn: 'Container Transport',
      axleCounts: [3, 4, 5],
      bodyTypeIds: ['container'],
      capacities: const [
        TruckCapacity(
          id: '25_30',
          labelAr: '٢٥–٣٠ طن',
          minTons: 25,
          maxTons: 30,
          defaultTons: 27.5,
        ),
        TruckCapacity(
          id: '30_40',
          labelAr: '٣٠–٤٠ طن',
          minTons: 30,
          maxTons: 40,
          defaultTons: 35,
        ),
      ],
      defaultBodyTypeId: 'container',
    ),
    TruckCategory(
      id: 'spec_hazmat',
      group: TruckGroup.specialized,
      labelAr: 'نقل مواد خطرة',
      labelEn: 'Hazardous Materials Transport',
      axleCounts: [2, 3],
      bodyTypeIds: ['hazmat', 'tanker'],
      capacities: const [
        TruckCapacity(
          id: '10_20',
          labelAr: '١٠–٢٠ طن',
          minTons: 10,
          maxTons: 20,
          defaultTons: 15,
        ),
        TruckCapacity(
          id: '20_30',
          labelAr: '٢٠–٣٠ طن',
          minTons: 20,
          maxTons: 30,
          defaultTons: 25,
        ),
      ],
      defaultBodyTypeId: 'hazmat',
    ),
  ];

  static TruckCategory? categoryById(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final c in categories) {
      if (c.id == id) return c;
    }
    return null;
  }

  static TruckBodyType? bodyTypeById(String? id) => bodyTypes[id];

  static TruckCapacity? capacityById(TruckCategory category, String? id) {
    if (id == null) return null;
    for (final cap in category.capacities) {
      if (cap.id == id) return cap;
    }
    return null;
  }

  static List<TruckCategory> categoriesForGroup(TruckGroup group) =>
      categories.where((c) => c.group == group).toList();

  static const Map<String, Map<String, dynamic>> legacyArabicTypeMap = {
    'دباب نقل': {
      'category': 'light_single_1_3',
      'axle_count': 1,
      'body_type': 'standard_cargo',
      'payload_capacity': '1_3',
    },
    'وانيت': {
      'category': 'light_single_3_5',
      'axle_count': 1,
      'body_type': 'open_bed',
      'payload_capacity': '3_5',
    },
    'دينا': {
      'category': 'medium_double_5_10',
      'axle_count': 2,
      'body_type': 'box',
      'payload_capacity': '5_10',
    },
    'لوري': {
      'category': 'medium_double_10_15',
      'axle_count': 2,
      'body_type': 'box',
      'payload_capacity': '10_15',
    },
    'سطحة': {
      'category': 'spec_car_carrier',
      'axle_count': 2,
      'body_type': 'car_carrier',
      'payload_capacity': 'var_8_12',
    },
    'تريلا جوانب': {
      'category': 'heavy_flatbed_trailer_25_40',
      'axle_count': 3,
      'body_type': 'flatbed',
      'payload_capacity': '30_35',
    },
    'تريلا ستارة': {
      'category': 'heavy_curtain_trailer_25_40',
      'axle_count': 3,
      'body_type': 'curtain_side',
      'payload_capacity': '30_35',
    },
    'برادة': {
      'category': 'heavy_reefer_trailer_20_35',
      'axle_count': 3,
      'body_type': 'refrigerated',
      'payload_capacity': '25_30',
    },
    'صهريج': {
      'category': 'heavy_tanker_variable',
      'axle_count': 3,
      'body_type': 'tanker',
      'payload_capacity': '20_30',
    },
    'قلاب': {
      'category': 'heavy_dump_20_40',
      'axle_count': 3,
      'body_type': 'dump',
      'payload_capacity': '25_30',
    },
    'مبرد': {
      'category': 'heavy_reefer_trailer_20_35',
      'axle_count': 3,
      'body_type': 'refrigerated',
      'payload_capacity': '20_25',
    },
  };
}
