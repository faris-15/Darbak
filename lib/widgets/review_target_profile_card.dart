import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../app_theme.dart';
import '../models/review_target_profile.dart';

/// بطاقة المستخدم المُقيَّم (RTL): صورة شبكة أو حرف أول على خلفية خضراء.
class ReviewTargetProfileCard extends StatelessWidget {
  static final Map<String, String> _stableUrlsByCacheKey = <String, String>{};

  final bool isLoading;
  final ReviewTargetProfile? profile;
  final String fallbackName;
  final String fallbackRoleLabel;

  const ReviewTargetProfileCard({
    super.key,
    required this.isLoading,
    required this.profile,
    required this.fallbackName,
    required this.fallbackRoleLabel,
  });

  String? _cacheKeyFor(String? key, String? url) {
    final k = key?.trim();
    if (k != null && k.isNotEmpty) return 'review-profile:$k';
    final u = url?.trim();
    return u != null && u.isNotEmpty ? u : null;
  }

  String? _stableUrlFor(String? cacheKey, String? url) {
    if (cacheKey == null || cacheKey.isEmpty || url == null || url.isEmpty) {
      return url;
    }
    return _stableUrlsByCacheKey.putIfAbsent(cacheKey, () => url);
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return _ReviewTargetProfileShimmerCard();
    }

    final p = profile;
    final displayName =
        (p != null && p.name.isNotEmpty) ? p.name : fallbackName;
    final roleLabel =
        (p != null && p.roleLabelAr.isNotEmpty) ? p.roleLabelAr : fallbackRoleLabel;

    final rawUrl = p?.profileImageUrl?.trim();
    final cacheKey = _cacheKeyFor(p?.profileImageKey, rawUrl);
    final imageUrl = _stableUrlFor(cacheKey, rawUrl);
    final initial =
        p != null ? p.nameInitial : ReviewTargetProfile.initialFor(displayName);

    return Card(
      elevation: 0,
      color: DarbakColors.cardBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          textDirection: TextDirection.rtl,
          children: [
            _Avatar(
              radius: 30,
              imageUrl: imageUrl,
              cacheKey: cacheKey,
              initial: initial,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: DarbakColors.dark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    roleLabel,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 12,
                      color: DarbakColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final double radius;
  final String? imageUrl;
  final String? cacheKey;
  final String initial;

  const _Avatar({
    required this.radius,
    required this.imageUrl,
    required this.cacheKey,
    required this.initial,
  });

  @override
  Widget build(BuildContext context) {
    final size = radius * 2;
    final url = imageUrl?.trim();

    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: url == null || url.isEmpty
            ? _InitialCircle(radius: radius, initial: initial)
            : CachedNetworkImage(
                imageUrl: url,
                cacheKey: cacheKey,
                useOldImageOnUrlChange: true,
                fadeInDuration: Duration.zero,
                fadeOutDuration: Duration.zero,
                fit: BoxFit.cover,
                placeholder: (context, _) =>
                    _InitialCircle(radius: radius, initial: initial),
                errorWidget: (context, url, error) =>
                    _InitialCircle(radius: radius, initial: initial),
              ),
      ),
    );
  }
}

class _InitialCircle extends StatelessWidget {
  final double radius;
  final String initial;

  const _InitialCircle({required this.radius, required this.initial});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: DarbakColors.primaryGreen,
      child: Text(
        initial,
        style: TextStyle(
          fontSize: radius * 0.95,
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ReviewTargetProfileShimmerCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: DarbakColors.cardBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Shimmer.fromColors(
          baseColor: Colors.grey.shade300,
          highlightColor: Colors.grey.shade100,
          child: Row(
            textDirection: TextDirection.rtl,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 16,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      height: 12,
                      width: 80,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
