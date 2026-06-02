import 'package:flutter_test/flutter_test.dart';
import 'package:darbak/utils/sar_formatter.dart';

void main() {
  group('SarFormatter.parse', () {
    test('parses numbers and numeric strings', () {
      expect(SarFormatter.parse(12), 12);
      expect(SarFormatter.parse(12.5), 12.5);
      expect(SarFormatter.parse('1,234.50'), 1234.5);
    });

    test('parses Arabic and Eastern Arabic digits with currency text', () {
      expect(SarFormatter.parse('١٢٣٫٤٥'), isNull);
      expect(SarFormatter.parse('١٢٣.٤٥ ر.س'), 123.45);
      expect(SarFormatter.parse('۱۲۳.۴۵ ريال'), 123.45);
      expect(SarFormatter.parse('⃁ 1,250 SAR'), 1250);
    });

    test('returns null for null, empty, and non-finite values', () {
      expect(SarFormatter.parse(null), isNull);
      expect(SarFormatter.parse(''), isNull);
      expect(SarFormatter.parse('abc'), isNull);
      expect(SarFormatter.parse(double.infinity), isNull);
    });
  });

  group('SarFormatter.formatAmount', () {
    test('formats valid amounts without the icon symbol', () {
      expect(SarFormatter.formatAmount(1234.5), '1,234.50');
      expect(SarFormatter.formatAmount('1234.5', decimalDigits: 0), '1,235');
    });

    test('returns Arabic fallback for invalid values', () {
      expect(SarFormatter.formatAmount('not-money'), 'غير محدد');
    });
  });

  group('SarFormatter.isValidAmount', () {
    test('validates positive bounded database values', () {
      expect(SarFormatter.isValidAmount(1), isTrue);
      expect(SarFormatter.isValidAmount(SarFormatter.maxDatabaseAmount), isTrue);
      expect(SarFormatter.isValidAmount(0), isFalse);
      expect(SarFormatter.isValidAmount(-1), isFalse);
      expect(
        SarFormatter.isValidAmount(SarFormatter.maxDatabaseAmount + 0.01),
        isFalse,
      );
    });
  });
}
