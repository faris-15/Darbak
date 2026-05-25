import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api_service.dart';

class ProfileImageState {
  final String? imageUrl;
  final String? imageKey;
  final String role;

  const ProfileImageState({this.imageUrl, this.imageKey, this.role = 'driver'});

  ProfileImageState copyWith({
    String? imageUrl,
    String? imageKey,
    String? role,
    bool clearImage = false,
  }) {
    return ProfileImageState(
      imageUrl: clearImage ? null : imageUrl ?? this.imageUrl,
      imageKey: clearImage ? null : imageKey ?? this.imageKey,
      role: role ?? this.role,
    );
  }
}

class ProfileRepository {
  static final ValueNotifier<ProfileImageState> profileImageNotifier =
      ValueNotifier<ProfileImageState>(const ProfileImageState());

  static Future<void> hydrateFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final imageUrl = prefs.getString('profile_image_url');
    final imageKey = prefs.getString('profile_image_key');
    profileImageNotifier.value = ProfileImageState(
      imageUrl: prefs.getString('profile_image_url'),
      imageKey: prefs.getString('profile_image_key'),
      role: prefs.getString('user_role') ?? 'driver',
    );
    unawaited(preloadProfileImage(imageUrl: imageUrl, imageKey: imageKey));
  }

  static Future<Map<String, dynamic>> getMe() async {
    final profile = await ApiService.getMyProfile();
    await cacheProfile(profile);
    return profile;
  }

  static Future<Map<String, dynamic>> updateProfile(
    Map<String, dynamic> data,
  ) async {
    final profile = await ApiService.updateCurrentProfile(data);
    await cacheProfile(profile);
    return profile;
  }

  static Future<Map<String, dynamic>> uploadProfileImage({
    required String fileName,
    required Uint8List bytes,
    ValueChanged<double>? onProgress,
  }) async {
    final response = await ApiService.uploadProfileImage(
      fileName: fileName,
      bytes: bytes,
      onProgress: onProgress,
    );
    await _cacheProfileImage(
      imageUrl: response['profileImageUrl']?.toString(),
      imageKey: response['profileImageKey']?.toString(),
    );
    return response;
  }

  static Future<Map<String, dynamic>> removeProfileImage() async {
    final response = await ApiService.removeProfileImage();
    await _cacheProfileImage(imageUrl: null, imageKey: null, clearImage: true);
    return response;
  }

  static Future<void> cacheProfile(Map<String, dynamic> profile) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = profile['id'];
    final imageUrl =
        profile['profileImageUrl']?.toString() ??
        profile['profile_image_url']?.toString();
    final imageKey = profile['profileImageKey']?.toString();
    final role =
        profile['role']?.toString() ?? prefs.getString('user_role') ?? 'driver';

    if (userId is int) {
      await prefs.setInt('user_id', userId);
    } else if (userId is num) {
      await prefs.setInt('user_id', userId.toInt());
    } else {
      final parsedUserId = int.tryParse(userId?.toString() ?? '');
      if (parsedUserId != null) await prefs.setInt('user_id', parsedUserId);
    }
    await prefs.setString('user_role', role);
    if (profile['full_name'] != null) {
      await prefs.setString('user_name', profile['full_name'].toString());
    }
    if (profile['email'] != null) {
      await prefs.setString('user_email', profile['email'].toString());
    }
    final verificationStatus = profile['verification_status']?.toString();
    if (verificationStatus != null && verificationStatus.isNotEmpty) {
      await prefs.setString('verification_status', verificationStatus);
    }
    await _cacheProfileImage(
      imageUrl: imageUrl,
      imageKey: imageKey,
      role: role,
    );
  }

  static Future<void> _cacheProfileImage({
    required String? imageUrl,
    required String? imageKey,
    String? role,
    bool clearImage = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final nextRole =
        role ?? prefs.getString('user_role') ?? profileImageNotifier.value.role;

    if (clearImage || imageUrl == null || imageUrl.isEmpty) {
      await prefs.remove('profile_image_url');
    } else {
      await prefs.setString('profile_image_url', imageUrl);
    }

    if (clearImage || imageKey == null || imageKey.isEmpty) {
      await prefs.remove('profile_image_key');
    } else {
      await prefs.setString('profile_image_key', imageKey);
    }

    profileImageNotifier.value = ProfileImageState(
      imageUrl: clearImage ? null : imageUrl,
      imageKey: clearImage ? null : imageKey,
      role: nextRole,
    );

    if (!clearImage) {
      await preloadProfileImage(imageUrl: imageUrl, imageKey: imageKey);
    }
  }

  static Future<void> preloadProfileImagesFromRows(
    Iterable<Map<String, dynamic>> rows, {
    required String urlField,
    required String keyField,
  }) async {
    await Future.wait(
      rows.map(
        (row) => preloadProfileImage(
          imageUrl: row[urlField]?.toString(),
          imageKey: row[keyField]?.toString(),
        ),
      ),
    );
  }

  static Future<void> preloadProfileImage({
    required String? imageUrl,
    required String? imageKey,
  }) async {
    final cleanedUrl = _cleanString(imageUrl);
    if (cleanedUrl == null) return;

    final provider = CachedNetworkImageProvider(
      cleanedUrl,
      cacheKey: stableCacheKey(imageKey, cleanedUrl),
    );
    final stream = provider.resolve(ImageConfiguration.empty);
    final completer = Completer<void>();
    late final ImageStreamListener listener;

    listener = ImageStreamListener(
      (imageInfo, synchronousCall) {
        if (!completer.isCompleted) completer.complete();
        stream.removeListener(listener);
      },
      onError: (error, stackTrace) {
        if (!completer.isCompleted) completer.complete();
        stream.removeListener(listener);
      },
    );

    stream.addListener(listener);
    await completer.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        stream.removeListener(listener);
      },
    );
  }

  static String? stableCacheKey(String? imageKey, String? imageUrl) {
    final cleanedKey = _cleanString(imageKey);
    if (cleanedKey != null) return 'profile-image:$cleanedKey';
    return _cleanString(imageUrl);
  }

  static String? _cleanString(String? value) {
    final text = value?.trim();
    if (text == null || text.isEmpty || text == 'null') return null;
    return text;
  }
}
