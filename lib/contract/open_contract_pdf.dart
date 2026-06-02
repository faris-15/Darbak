import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../api_service.dart';

/// يفتح رابط العقد في متصفح الجهاز الخارجي أو عارض الـ PDF
Future<void> openShipmentContractPdfInApp(
  BuildContext context,
  int shipmentId, {
  Future<String?> Function(int shipmentId)? getSignedUrl,
  Future<bool> Function(Uri url, LaunchMode mode)? launch,
}) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final fetchSignedUrl =
      getSignedUrl ?? ApiService.getShipmentContractSignedUrl;
  final launchExternal = launch ?? (url, mode) => launchUrl(url, mode: mode);

  try {
    // 1. جلب الرابط الموقع من السيرفر
    final urlStr = await fetchSignedUrl(shipmentId);

    if (urlStr == null || urlStr.isEmpty) {
      messenger?.showSnackBar(
        const SnackBar(
          content: Text('تعذر جلب رابط العقد. تأكد من وجود العقد في النظام.'),
        ),
      );
      return;
    }

    final Uri url = Uri.parse(urlStr);

    // 2. محاولة فتح الرابط مباشرة
    // ملاحظة: تم استخدام LaunchMode.externalApplication لضمان استجابة نظام أندرويد لملفات PDF
    try {
      final launched = await launchExternal(
        url,
        LaunchMode.externalApplication,
      );

      if (!launched) {
        throw 'Could not launch URL';
      }
    } catch (e) {
      debugPrint('Launch Error: $e');
      messenger?.showSnackBar(
        const SnackBar(
          content: Text(
            'لا يمكن فتح الرابط. يرجى التأكد من وجود متصفح إنترنت مثبت.',
          ),
        ),
      );
    }
  } catch (e) {
    messenger?.showSnackBar(
      SnackBar(content: Text('حدث خطأ أثناء فتح العقد: $e')),
    );
  }
}
