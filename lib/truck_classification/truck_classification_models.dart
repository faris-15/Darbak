enum TruckGroup { light, medium, heavy, specialized }

extension TruckGroupLabels on TruckGroup {
  String get labelAr {
    switch (this) {
      case TruckGroup.light:
        return 'شاحنات خفيفة';
      case TruckGroup.medium:
        return 'شاحنات متوسطة';
      case TruckGroup.heavy:
        return 'شاحنات ثقيلة';
      case TruckGroup.specialized:
        return 'شاحنات متخصصة';
    }
  }

  String get id {
    switch (this) {
      case TruckGroup.light:
        return 'light';
      case TruckGroup.medium:
        return 'medium';
      case TruckGroup.heavy:
        return 'heavy';
      case TruckGroup.specialized:
        return 'specialized';
    }
  }

  static TruckGroup? fromId(String? value) {
    switch (value) {
      case 'light':
        return TruckGroup.light;
      case 'medium':
        return TruckGroup.medium;
      case 'heavy':
        return TruckGroup.heavy;
      case 'specialized':
        return TruckGroup.specialized;
      default:
        return null;
    }
  }
}

class TruckBodyType {
  const TruckBodyType({
    required this.id,
    required this.labelAr,
    required this.labelEn,
  });

  final String id;
  final String labelAr;
  final String labelEn;
}

class TruckCapacity {
  const TruckCapacity({
    required this.id,
    required this.labelAr,
    required this.minTons,
    required this.maxTons,
    required this.defaultTons,
  });

  final String id;
  final String labelAr;
  final double minTons;
  final double maxTons;
  final double defaultTons;
}

class TruckCategory {
  const TruckCategory({
    required this.id,
    required this.group,
    required this.labelAr,
    required this.labelEn,
    required this.axleCounts,
    required this.bodyTypeIds,
    required this.capacities,
    required this.defaultBodyTypeId,
  });

  final String id;
  final TruckGroup group;
  final String labelAr;
  final String labelEn;
  final List<int> axleCounts;
  final List<String> bodyTypeIds;
  final List<TruckCapacity> capacities;
  final String defaultBodyTypeId;
}

class TruckAxleType {
  const TruckAxleType({required this.count, required this.labelAr});

  final int count;
  final String labelAr;
}

/// Resolved selection ready for API submission.
class TruckConfiguration {
  const TruckConfiguration({
    required this.categoryId,
    required this.axleCount,
    required this.bodyTypeId,
    required this.payloadCapacityId,
    required this.maxWeightTons,
    required this.displayLabelAr,
  });

  final String categoryId;
  final int axleCount;
  final String bodyTypeId;
  final String payloadCapacityId;
  final double maxWeightTons;
  final String displayLabelAr;

  Map<String, dynamic> toApiPayload() => {
    'category': categoryId,
    'axle_count': axleCount,
    'body_type': bodyTypeId,
    'payload_capacity': payloadCapacityId,
    'max_weight_tons': maxWeightTons,
    'truck_type': displayLabelAr,
    'capacity_kg': (maxWeightTons * 1000).round(),
  };

  factory TruckConfiguration.fromJson(Map<String, dynamic> json) {
    final classification = json['classification'];
    final map = classification is Map
        ? Map<String, dynamic>.from(classification)
        : json;

    return TruckConfiguration(
      categoryId: map['category']?.toString() ?? '',
      axleCount: int.tryParse(map['axle_count']?.toString() ?? '') ?? 0,
      bodyTypeId: map['body_type']?.toString() ?? '',
      payloadCapacityId: map['payload_capacity']?.toString() ?? '',
      maxWeightTons:
          double.tryParse(map['max_weight_tons']?.toString() ?? '') ?? 0,
      displayLabelAr: json['truck_type']?.toString() ?? '',
    );
  }
}
