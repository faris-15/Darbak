import 'package:characters/characters.dart';

/// بيانات المستخدم المعروضة في بطاقة أعلى شاشة التقييم (من الخادم).
class ReviewTargetProfile {
  final int id;
  final String name;
  final String? profileImageUrl;
  final String? profileImageKey;
  final String role;
  final String roleLabelAr;

  const ReviewTargetProfile({
    required this.id,
    required this.name,
    this.profileImageUrl,
    this.profileImageKey,
    required this.role,
    required this.roleLabelAr,
  });

  static String initialFor(String name) {
    final t = name.trim();
    if (t.isEmpty) return '?';
    return t.characters.first;
  }

  String get nameInitial => initialFor(name);

  factory ReviewTargetProfile.fromJson(Map<String, dynamic> json) {
    final idVal = json['id'];
    final id = idVal is int
        ? idVal
        : int.tryParse(idVal?.toString() ?? '') ?? 0;

    final rawUrl = json['profile_image'] ??
        json['profileImageUrl'] ??
        json['profile_image_url'];
    final url = rawUrl?.toString().trim();
    final rawKey = json['profileImageKey'];
    final key = rawKey?.toString().trim();

    final roleRaw = (json['role'] ?? 'driver').toString().toLowerCase();
    final role = roleRaw == 'shipper' ? 'shipper' : 'driver';

    final label = json['role_label_ar']?.toString().trim();
    final roleLabelAr = (label != null && label.isNotEmpty)
        ? label
        : (role == 'driver' ? 'سائق' : 'شركة');

    return ReviewTargetProfile(
      id: id,
      name: (json['name'] ?? json['full_name'] ?? '').toString().trim(),
      profileImageUrl: url != null && url.isNotEmpty ? url : null,
      profileImageKey: key != null && key.isNotEmpty ? key : null,
      role: role,
      roleLabelAr: roleLabelAr,
    );
  }
}
