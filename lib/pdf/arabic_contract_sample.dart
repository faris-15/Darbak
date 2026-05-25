import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/widgets.dart' as pw;

/// Sample Arabic contract for the [`pdf`](https://pub.dev/packages/pdf) package.
///
/// Uses **only** `assets/noto/NotoSansArabic-Regular.ttf` (declare in `pubspec.yaml`).
/// Every [pw.Text] sets [pw.TextStyle.font] explicitly so the default Helvetica
/// is never used.
Future<Uint8List> buildArabicContractSamplePdf({
  String shipperName = 'شركة الشحن',
  String driverName = 'اسم السائق',
  String fromCity = 'الرياض',
  String toCity = 'جدة',
  String amountSar = '800.00',
  String distanceKm = '850',
}) async {
  final fontData = await rootBundle.load(
    'assets/noto/NotoSansArabic-Regular.ttf',
  );
  final sarIconData = await rootBundle.load('assets/icons/saudi_riyal.png');
  final font = pw.Font.ttf(fontData);
  final sarIcon = pw.MemoryImage(sarIconData.buffer.asUint8List());

  pw.TextStyle ts(double size, {pw.FontWeight? w}) =>
      pw.TextStyle(font: font, fontSize: size, fontWeight: w);

  final doc = pw.Document(
    theme: pw.ThemeData.withFont(base: font, bold: font),
  );

  doc.addPage(
    pw.MultiPage(
      textDirection: pw.TextDirection.rtl,
      pageTheme: const pw.PageTheme(textDirection: pw.TextDirection.rtl),
      build: (ctx) => [
        pw.Text('عنوان العقد', style: ts(18, w: pw.FontWeight.bold)),
        pw.SizedBox(height: 6),
        pw.Text('عقد نقل تجاري نموذجي — دربك', style: ts(12)),
        pw.SizedBox(height: 16),
        pw.Text('تفاصيل الرحلة', style: ts(14, w: pw.FontWeight.bold)),
        pw.SizedBox(height: 6),
        pw.Text('من: $fromCity', style: ts(11)),
        pw.Text('إلى: $toCity', style: ts(11)),
        pw.Text('المسافة تقريباً: $distanceKm كم', style: ts(11)),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.end,
          children: [
            pw.Text(amountSar, style: ts(11)),
            pw.SizedBox(width: 3),
            pw.Image(sarIcon, width: 10, height: 10),
            pw.SizedBox(width: 3),
            pw.Text('السعر:', style: ts(11)),
          ],
        ),
        pw.SizedBox(height: 16),
        pw.Text('بيانات السائق', style: ts(14, w: pw.FontWeight.bold)),
        pw.SizedBox(height: 6),
        pw.Text('الاسم: $driverName', style: ts(11)),
        pw.SizedBox(height: 16),
        pw.Text('بيانات الشركة', style: ts(14, w: pw.FontWeight.bold)),
        pw.SizedBox(height: 6),
        pw.Text('الاسم: $shipperName', style: ts(11)),
        pw.SizedBox(height: 16),
        pw.Text('الشروط والأحكام', style: ts(14, w: pw.FontWeight.bold)),
        pw.SizedBox(height: 6),
        pw.Text(
          'يلتزم الطرفان بتنفيذ النقل وفق البيانات أعلاه والأنظمة المعمول بها. '
          'يُعد هذا النموذج مرجعاً تقنياً لاستخدام خط Noto Sans Arabic فقط داخل حزمة pdf.',
          style: ts(10),
          textAlign: pw.TextAlign.right,
        ),
      ],
    ),
  );

  return doc.save();
}
