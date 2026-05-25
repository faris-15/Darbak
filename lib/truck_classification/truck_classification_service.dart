import 'truck_classification_catalog.dart';
import 'truck_classification_models.dart';

/// Dependent dropdown logic and validation for truck configuration forms.
class TruckClassificationService {
  const TruckClassificationService();

  List<TruckGroup> get groups => TruckGroup.values;

  List<TruckCategory> categoriesForGroup(TruckGroup? group) {
    if (group == null) return [];
    return TruckClassificationCatalog.categoriesForGroup(group);
  }

  TruckCategory? categoryById(String? id) =>
      TruckClassificationCatalog.categoryById(id);

  List<int> axleOptions(TruckCategory? category) => category?.axleCounts ?? [];

  List<TruckBodyType> bodyTypeOptions(TruckCategory? category) {
    if (category == null) return [];
    return category.bodyTypeIds
        .map(TruckClassificationCatalog.bodyTypeById)
        .whereType<TruckBodyType>()
        .toList();
  }

  List<TruckCapacity> capacityOptions(TruckCategory? category) =>
      category?.capacities ?? [];

  TruckGroup? groupForCategory(TruckCategory? category) => category?.group;

  String buildDisplayLabel({
    required TruckCategory category,
    required int axleCount,
    required TruckBodyType bodyType,
    required TruckCapacity capacity,
  }) {
    return '${category.labelAr} · $axleCount محور · ${bodyType.labelAr} · ${capacity.labelAr}';
  }

  /// Validates and builds [TruckConfiguration] for API calls.
  String? validateSelection({
    TruckGroup? group,
    String? categoryId,
    int? axleCount,
    String? bodyTypeId,
    String? capacityId,
  }) {
    if (group == null) return 'اختر مجموعة الشاحنة';
    final category = categoryById(categoryId);
    if (category == null || category.group != group) {
      return 'اختر فئة الشاحنة';
    }
    if (axleCount == null || !category.axleCounts.contains(axleCount)) {
      return 'اختر عدد المحاور';
    }
    if (bodyTypeId == null || !category.bodyTypeIds.contains(bodyTypeId)) {
      return 'اختر نوع الهيكل';
    }
    final capacity = TruckClassificationCatalog.capacityById(category, capacityId);
    if (capacity == null) return 'اختر الحمولة القصوى';
    return null;
  }

  TruckConfiguration? resolveConfiguration({
    TruckGroup? group,
    String? categoryId,
    int? axleCount,
    String? bodyTypeId,
    String? capacityId,
  }) {
    final error = validateSelection(
      group: group,
      categoryId: categoryId,
      axleCount: axleCount,
      bodyTypeId: bodyTypeId,
      capacityId: capacityId,
    );
    if (error != null) return null;

    final category = categoryById(categoryId)!;
    final body = TruckClassificationCatalog.bodyTypeById(bodyTypeId)!;
    final capacity = TruckClassificationCatalog.capacityById(category, capacityId)!;

    return TruckConfiguration(
      categoryId: category.id,
      axleCount: axleCount!,
      bodyTypeId: body.id,
      payloadCapacityId: capacity.id,
      maxWeightTons: capacity.defaultTons,
      displayLabelAr: buildDisplayLabel(
        category: category,
        axleCount: axleCount,
        bodyType: body,
        capacity: capacity,
      ),
    );
  }

  /// Picks a sensible default category from cargo weight (tons).
  String? suggestCategoryIdForWeightTons(double weightTons) {
    if (weightTons <= 3) return 'light_single_1_3';
    if (weightTons <= 5) return 'light_single_3_5';
    if (weightTons <= 10) return 'medium_double_5_10';
    if (weightTons <= 15) return 'medium_double_10_15';
    if (weightTons <= 25) return 'heavy_triple_15_25';
    if (weightTons <= 35) return 'heavy_curtain_trailer_25_40';
    return 'heavy_flatbed_trailer_25_40';
  }

  TruckGroup? suggestGroupForWeightTons(double weightTons) {
    final categoryId = suggestCategoryIdForWeightTons(weightTons);
    return categoryById(categoryId)?.group;
  }

  /// Hydrates form state from API / legacy truck row.
  ({
    TruckGroup? group,
    String? categoryId,
    int? axleCount,
    String? bodyTypeId,
    String? capacityId,
  }) selectionFromTruckJson(Map<String, dynamic> json) {
    final classification = json['classification'];
    String? categoryId;
    int? axleCount;
    String? bodyTypeId;
    String? capacityId;

    if (classification is Map) {
      categoryId = classification['category']?.toString();
      axleCount = int.tryParse(classification['axle_count']?.toString() ?? '');
      bodyTypeId = classification['body_type']?.toString();
      capacityId = classification['payload_capacity']?.toString();
    } else {
      categoryId = json['category']?.toString();
      axleCount = int.tryParse(json['axle_count']?.toString() ?? '');
      bodyTypeId = json['body_type']?.toString();
      capacityId = json['payload_capacity']?.toString();
    }

    if ((categoryId == null || categoryId.isEmpty) &&
        json['truck_type'] != null) {
      final legacy = TruckClassificationCatalog.legacyArabicTypeMap[
          json['truck_type']?.toString()];
      if (legacy != null) {
        categoryId = legacy['category'] as String?;
        axleCount = legacy['axle_count'] as int?;
        bodyTypeId = legacy['body_type'] as String?;
        capacityId = legacy['payload_capacity'] as String?;
      }
    }

    final category = categoryById(categoryId);
    return (
      group: category?.group,
      categoryId: categoryId,
      axleCount: axleCount,
      bodyTypeId: bodyTypeId,
      capacityId: capacityId,
    );
  }
}
