import 'package:intl/intl.dart';

class SarFormatter {
  static const String symbol = '⃁';
  static const double maxDatabaseAmount = 99999999.99;

  static String format(dynamic value, {int decimalDigits = 2}) {
    return formatAmount(value, decimalDigits: decimalDigits);
  }

  static String formatAmount(dynamic value, {int decimalDigits = 2}) {
    final amount = parse(value);
    if (amount == null) return 'غير محدد';

    return NumberFormat.currency(
      locale: 'en_US',
      symbol: '',
      decimalDigits: decimalDigits,
    ).format(amount).trim();
  }

  static double? parse(dynamic value) {
    if (value == null) return null;
    if (value is num && value.isFinite) return value.toDouble();

    final normalized = _normalizeDigits(value.toString())
        .replaceAll(',', '')
        .replaceAll('٬', '')
        .replaceAll(symbol, '')
        .replaceAll('ر.س', '')
        .replaceAll('ر.s', '')
        .replaceAll('ر.S', '')
        .replaceAll('ريال', '')
        .replaceAll(RegExp('sar', caseSensitive: false), '')
        .trim();

    if (normalized.isEmpty) return null;
    final parsed = double.tryParse(normalized);
    return parsed != null && parsed.isFinite ? parsed : null;
  }

  static bool isValidAmount(dynamic value, {double max = maxDatabaseAmount}) {
    final amount = parse(value);
    return amount != null && amount > 0 && amount <= max;
  }

  static String _normalizeDigits(String value) {
    const arabicIndic = '٠١٢٣٤٥٦٧٨٩';
    const easternArabic = '۰۱۲۳۴۵۶۷۸۹';
    var result = value;

    for (var i = 0; i < 10; i++) {
      result = result
          .replaceAll(arabicIndic[i], i.toString())
          .replaceAll(easternArabic[i], i.toString());
    }

    return result;
  }
}
