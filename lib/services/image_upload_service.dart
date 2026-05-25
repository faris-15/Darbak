import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

import '../api_service.dart';

class PickedProfileImage {
  final String fileName;
  final Uint8List bytes;

  const PickedProfileImage({required this.fileName, required this.bytes});
}

class ImageUploadService {
  static const int maxProfileImageBytes = 5 * 1024 * 1024;
  static const Set<String> allowedProfileExtensions = {
    'jpg',
    'jpeg',
    'png',
    'webp',
  };

  static final ImagePicker _picker = ImagePicker();

  static Future<PickedProfileImage?> pickProfileImage(
    ImageSource source,
  ) async {
    final image = await _picker.pickImage(
      source: source,
      imageQuality: 82,
      maxWidth: 1200,
      maxHeight: 1200,
    );
    if (image == null) return null;

    final extension = _extensionOf(image.name);
    if (!allowedProfileExtensions.contains(extension)) {
      throw DarbakException(
        'نوع الصورة غير مدعوم. الصيغ المسموحة: jpg, jpeg, png, webp',
      );
    }

    final bytes = await image.readAsBytes();
    if (bytes.isEmpty) {
      throw DarbakException('الصورة فارغة');
    }
    if (bytes.length > maxProfileImageBytes) {
      throw DarbakException('حجم الصورة يجب ألا يتجاوز 5 ميجابايت');
    }

    return PickedProfileImage(
      fileName: _safeProfileFileName(extension),
      bytes: bytes,
    );
  }

  static String _extensionOf(String fileName) {
    final dotIndex = fileName.lastIndexOf('.');
    if (dotIndex < 0 || dotIndex == fileName.length - 1) return 'jpg';
    return fileName.substring(dotIndex + 1).toLowerCase();
  }

  static String _safeProfileFileName(String extension) {
    final safeExtension = extension == 'jpeg' ? 'jpg' : extension;
    return 'profile.$safeExtension';
  }
}
