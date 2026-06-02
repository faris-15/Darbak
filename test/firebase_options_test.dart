import 'package:darbak/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DefaultFirebaseOptions', () {
    test('android constant is populated with project metadata', () {
      const opts = DefaultFirebaseOptions.android;
      expect(opts.appId, contains('android'));
      expect(opts.projectId, 'darbak-7ecc0');
      expect(opts.messagingSenderId, isNotEmpty);
    });

    test('ios constant carries the iOS bundle identifier', () {
      const opts = DefaultFirebaseOptions.ios;
      expect(opts.iosBundleId, isNotNull);
      expect(opts.projectId, 'darbak-7ecc0');
    });

    test('currentPlatform returns android on Android', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      expect(DefaultFirebaseOptions.currentPlatform, isA<FirebaseOptions>());
      expect(
        DefaultFirebaseOptions.currentPlatform.appId,
        DefaultFirebaseOptions.android.appId,
      );
    });

    test('currentPlatform returns ios on iOS', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      expect(
        DefaultFirebaseOptions.currentPlatform.iosBundleId,
        DefaultFirebaseOptions.ios.iosBundleId,
      );
    });

    for (final unsupported in const [
      TargetPlatform.macOS,
      TargetPlatform.windows,
      TargetPlatform.linux,
      TargetPlatform.fuchsia,
    ]) {
      test('currentPlatform throws UnsupportedError on $unsupported', () {
        debugDefaultTargetPlatformOverride = unsupported;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        expect(
          () => DefaultFirebaseOptions.currentPlatform,
          throwsA(isA<UnsupportedError>()),
        );
      });
    }
  });
}
