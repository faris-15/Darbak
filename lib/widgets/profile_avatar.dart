import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../app_theme.dart';

class ProfileAvatar extends StatelessWidget {
  static final Map<String, String> _stableUrlsByCacheKey = {};

  final String? imageUrl;
  final String? imageKey;
  final String role;
  final double radius;
  final bool showEditButton;
  final bool isUploading;
  final double? uploadProgress;
  final VoidCallback? onEdit;

  const ProfileAvatar({
    super.key,
    this.imageUrl,
    this.imageKey,
    required this.role,
    this.radius = 46,
    this.showEditButton = false,
    this.isUploading = false,
    this.uploadProgress,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final size = radius * 2;
    final cleanedUrl = imageUrl?.trim();
    final cacheKey = _cacheKeyFor(imageKey, cleanedUrl);
    final displayUrl = _stableUrlFor(cacheKey, cleanedUrl);

    return SizedBox(
      width: size + (showEditButton ? 10 : 0),
      height: size + (showEditButton ? 10 : 0),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: DarbakColors.lightBackground,
            ),
            clipBehavior: Clip.antiAlias,
            child: displayUrl == null || displayUrl.isEmpty
                ? _FallbackAvatar(role: role, radius: radius)
                : CachedNetworkImage(
                    imageUrl: displayUrl,
                    cacheKey: cacheKey,
                    useOldImageOnUrlChange: true,
                    fadeInDuration: Duration.zero,
                    fadeOutDuration: Duration.zero,
                    fit: BoxFit.cover,
                    placeholder: (context, url) =>
                        _FallbackAvatar(role: role, radius: radius),
                    errorWidget: (context, url, error) =>
                        _FallbackAvatar(role: role, radius: radius),
                  ),
          ),
          if (isUploading)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.28),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: SizedBox(
                    width: radius * 0.9,
                    height: radius * 0.9,
                    child: CircularProgressIndicator(
                      value: uploadProgress,
                      strokeWidth: 3,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          if (showEditButton)
            PositionedDirectional(
              bottom: 0,
              end: 0,
              child: Material(
                color: DarbakColors.primaryGreen,
                shape: const CircleBorder(),
                elevation: 3,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: isUploading ? null : onEdit,
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(
                      Icons.camera_alt_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String? _cacheKeyFor(String? key, String? url) {
    final cleanedKey = key?.trim();
    if (cleanedKey != null && cleanedKey.isNotEmpty) {
      return 'profile-image:$cleanedKey';
    }
    return url;
  }

  String? _stableUrlFor(String? cacheKey, String? url) {
    if (cacheKey == null || cacheKey.isEmpty || url == null || url.isEmpty) {
      return url;
    }
    return _stableUrlsByCacheKey.putIfAbsent(cacheKey, () => url);
  }
}

class _FallbackAvatar extends StatelessWidget {
  final String role;
  final double radius;

  const _FallbackAvatar({required this.role, required this.radius});

  IconData get _icon {
    return role == 'shipper' ? Icons.domain_rounded : Icons.person_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: DarbakColors.lightBackground,
      child: Icon(_icon, size: radius * 1.04, color: DarbakColors.primary),
    );
  }
}
