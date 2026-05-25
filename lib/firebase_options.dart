// ignore_for_file: lines_longer_than_80_chars
// ملف إعدادات Firebase للعميل — استبدل القيم بعد تشغيل:
// dart pub global run flutterfire_cli:flutterfire configure --project=darbak-7ecc0
//
// القيم أدناه نائبة؛ لن تعمل المصادقة حتى تُستبدل من وحدة تحكم Firebase
// (Project settings → Your apps → SDK setup).

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

/// Default [FirebaseOptions] for use with your Firebase apps.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'Firebase غير مهيأ للويب. أضف منصة web عبر flutterfire configure.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        throw UnsupportedError(
          'أضف تكوين Firebase لهذه المنصة عبر flutterfire configure أو شغّل على Android/iOS.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAIsSdWozob3lUF_a0yWMwkZW-30aAlnhY',
    appId: '1:176722015466:android:34e78176dc4b9020bad393',
    messagingSenderId: '176722015466',
    projectId: 'darbak-7ecc0',
    storageBucket: 'darbak-7ecc0.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'REPLACE_WITH_WEB_API_KEY_FROM_FIREBASE_CONSOLE',
    appId: '1:000000000001:ios:0000000000000000000000',
    messagingSenderId: '000000000001',
    projectId: 'darbak-7ecc0',
    storageBucket: 'darbak-7ecc0.firebasestorage.app',
    iosBundleId: 'com.example.darbak',
  );
}
