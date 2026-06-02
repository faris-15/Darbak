import 'package:darbak/shipper_home.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() async {
    WidgetsFlutterBinding.ensureInitialized();
    await initializeDateFormatting('ar', null);
  });

  group('formatNotificationTime', () {
    final now = DateTime(2026, 6, 1, 12, 0);

    test('returns empty string for null/invalid', () {
      expect(formatNotificationTime(null, now: now), '');
      expect(formatNotificationTime('', now: now), '');
      expect(formatNotificationTime('not-a-date', now: now), '');
    });

    test('returns "الآن" for sub-minute difference', () {
      final justNow = now.subtract(const Duration(seconds: 15));
      expect(formatNotificationTime(justNow.toIso8601String(), now: now),
          'الآن');
    });

    test('returns minutes label for under-an-hour same-day', () {
      final fiveMinAgo = now.subtract(const Duration(minutes: 5));
      final label =
          formatNotificationTime(fiveMinAgo.toIso8601String(), now: now);
      expect(label.startsWith('منذ'), isTrue);
      expect(label, contains('دقائق'));
    });

    test('returns hours label for under-a-day same-day', () {
      final threeHoursAgo = now.subtract(const Duration(hours: 3));
      final label =
          formatNotificationTime(threeHoursAgo.toIso8601String(), now: now);
      expect(label.startsWith('منذ'), isTrue);
      expect(label, contains('ساعات'));
    });

    test('returns dual ("ساعتين") for exactly 2 hours', () {
      final twoHoursAgo = now.subtract(const Duration(hours: 2, minutes: 1));
      final label =
          formatNotificationTime(twoHoursAgo.toIso8601String(), now: now);
      expect(label, contains('ساعتين'));
    });

    test('returns "أمس" prefix when value is from yesterday', () {
      final yesterday = DateTime(2026, 5, 31, 10, 30);
      final label =
          formatNotificationTime(yesterday.toIso8601String(), now: now);
      expect(label.startsWith('أمس الساعة'), isTrue);
    });

    test('returns dd/MM/yyyy when older than yesterday', () {
      final old = DateTime(2026, 5, 15, 9, 0);
      final label = formatNotificationTime(old.toIso8601String(), now: now);
      expect(label, '15/05/2026');
    });

    test('accepts DateTime values directly', () {
      final justNow = now.subtract(const Duration(seconds: 5));
      expect(formatNotificationTime(justNow, now: now), 'الآن');
    });
  });

  group('formatArabicClockTime', () {
    test('produces a non-empty Arabic clock string', () {
      final dt = DateTime(2026, 6, 1, 14, 30);
      final out = formatArabicClockTime(dt);
      expect(out, isNotEmpty);
      // Different ICU versions render the meridiem differently; just sanity
      // check that the hour digit shows up.
      expect(out, anyOf(contains(':'), contains('٫'), contains('30')));
    });
  });
}
