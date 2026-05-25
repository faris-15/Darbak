import 'dart:io';
import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:video_compress/video_compress.dart';

import '../api_service.dart';

class PickedChatMedia {
  const PickedChatMedia({
    required this.fileName,
    required this.bytes,
    required this.messageType,
  });

  final String fileName;
  final Uint8List bytes;
  final String messageType;
}

class ChatMediaService {
  static final ImagePicker _picker = ImagePicker();

  static Future<PickedChatMedia?> pickImage(ImageSource source) async {
    final image = await _picker.pickImage(
      source: source,
      imageQuality: 82,
      maxWidth: 1600,
      maxHeight: 1600,
    );
    if (image == null) return null;

    final extension = _extensionOf(image.name, fallback: 'jpg');
    final bytes = await image.readAsBytes();
    if (bytes.isEmpty) throw DarbakException('الصورة فارغة');
    if (bytes.length > ApiService.maxChatImageBytes) {
      throw DarbakException('حجم الصورة يجب ألا يتجاوز 10 ميجابايت');
    }
    return PickedChatMedia(
      fileName: _safeFileName('photo', extension),
      bytes: bytes,
      messageType: 'image',
    );
  }

  static Future<PickedChatMedia?> pickVideo(ImageSource source) async {
    final video = await _picker.pickVideo(
      source: source,
      maxDuration: const Duration(minutes: 2),
    );
    if (video == null) return null;

    final compressed = await VideoCompress.compressVideo(
      video.path,
      quality: VideoQuality.MediumQuality,
      includeAudio: true,
      deleteOrigin: false,
    );
    final path = compressed?.path ?? video.path;
    final bytes = await File(path).readAsBytes();
    if (bytes.isEmpty) throw DarbakException('الفيديو فارغ');
    if (bytes.length > ApiService.maxChatVideoBytes) {
      throw DarbakException('حجم الفيديو يجب ألا يتجاوز 50 ميجابايت');
    }
    final extension = _extensionOf(path, fallback: 'mp4');
    return PickedChatMedia(
      fileName: _safeFileName('video', extension),
      bytes: bytes,
      messageType: 'video',
    );
  }

  static String _extensionOf(String fileName, {required String fallback}) {
    final dotIndex = fileName.lastIndexOf('.');
    if (dotIndex < 0 || dotIndex == fileName.length - 1) return fallback;
    return fileName.substring(dotIndex + 1).toLowerCase();
  }

  static String _safeFileName(String prefix, String extension) {
    final safeExtension = extension == 'jpeg' ? 'jpg' : extension;
    return '$prefix-${DateTime.now().millisecondsSinceEpoch}.$safeExtension';
  }
}
