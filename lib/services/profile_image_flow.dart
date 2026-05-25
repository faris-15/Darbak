import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'image_upload_service.dart';
import 'profile_repository.dart';

enum ProfileImageAction { camera, gallery, remove }

class ProfileImageChange {
  final String? imageUrl;
  final String? imageKey;
  final bool removed;

  const ProfileImageChange({
    this.imageUrl,
    this.imageKey,
    this.removed = false,
  });
}

class ProfileImageFlow {
  static bool hasImage(Map<String, dynamic>? user) {
    return (user?['profileImageUrl'] ?? user?['profile_image_url'])
            ?.toString()
            .trim()
            .isNotEmpty ==
        true;
  }

  static Future<ProfileImageAction?> showActionSheet(
    BuildContext context, {
    required bool hasImage,
  }) {
    return showModalBottomSheet<ProfileImageAction>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) => SafeArea(
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera_rounded),
                title: const Text('التقاط صورة بالكاميرا'),
                onTap: () => Navigator.pop(context, ProfileImageAction.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded),
                title: const Text('اختيار من المعرض'),
                onTap: () => Navigator.pop(context, ProfileImageAction.gallery),
              ),
              if (hasImage)
                ListTile(
                  leading: const Icon(
                    Icons.delete_outline_rounded,
                    color: Colors.red,
                  ),
                  title: const Text(
                    'حذف الصورة',
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: () =>
                      Navigator.pop(context, ProfileImageAction.remove),
                ),
            ],
          ),
        ),
      ),
    );
  }

  static Future<ProfileImageChange?> uploadFromAction(
    ProfileImageAction action, {
    ValueChanged<double>? onProgress,
  }) async {
    final source = switch (action) {
      ProfileImageAction.camera => ImageSource.camera,
      ProfileImageAction.gallery => ImageSource.gallery,
      ProfileImageAction.remove => null,
    };
    if (source == null) return null;

    final picked = await ImageUploadService.pickProfileImage(source);
    if (picked == null) return null;

    final response = await ProfileRepository.uploadProfileImage(
      fileName: picked.fileName,
      bytes: picked.bytes,
      onProgress: onProgress,
    );

    return ProfileImageChange(
      imageUrl: response['profileImageUrl']?.toString(),
      imageKey: response['profileImageKey']?.toString(),
    );
  }

  static Future<ProfileImageChange> remove() async {
    await ProfileRepository.removeProfileImage();
    return const ProfileImageChange(removed: true);
  }

  static Map<String, dynamic> applyToProfile(
    Map<String, dynamic>? user,
    ProfileImageChange change,
  ) {
    return {
      ...?user,
      'profileImageUrl': change.removed ? null : change.imageUrl,
      'profile_image_url': change.removed ? null : change.imageUrl,
      'profileImageKey': change.removed ? null : change.imageKey,
    };
  }
}
