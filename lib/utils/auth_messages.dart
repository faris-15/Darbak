import 'package:firebase_auth/firebase_auth.dart';

import '../api_service.dart';

/// إخفاء أسماء مقدمي خدمة المصادقة من رسائل تُعرض في الواجهة.
String stripThirdPartyFromAuthMessage(String message) {
  final lower = message.toLowerCase();
  if (lower.contains('firebase') ||
      lower.contains('google') ||
      lower.contains('identitytoolkit') ||
      message.contains('فايربيس')) {
    return 'تعذّر إكمال العملية. حاول مرة أخرى.';
  }
  return message;
}

/// رسائل شاشة «نسيت كلمة المرور» — بدون تفاصيل تقنية للمستخدم.
String userFacingForgotPasswordMessage(Object error) {
  const noAccount = 'لا يوجد حساب بهذا البريد الإلكتروني أو أنّه غير صحيح.';
  if (error is DarbakException) {
    final message = error.message;
    final code = error.httpStatus;
    if (code == 429) return message;
    if (code == 400) return message;
    if (message.contains('لا يوجد حساب')) return message;
    if (code == 502 || code == 503) return message;
    if (code == 500) {
      return 'تعذّر إرسال الرابط حالياً. حاول لاحقاً.';
    }
    if (message.contains('تعذّر الاتصال بالخادم') ||
        message.contains('تعذر الاتصال بالخادم')) {
      return message;
    }
    return noAccount;
  }
  final text = error.toString();
  if (text.contains('SocketException') ||
      text.contains('Connection refused') ||
      text.contains('Failed host lookup')) {
    return 'تعذّر الاتصال بالخادم';
  }
  return noAccount;
}

/// إن ردّ الخادم يعني «المسار غير موجود» أو تعذّر sendOobCode نجرّب Firebase من التطبيق.
String firebaseLoginMessage(Object error) {
  if (error is DarbakException) {
    return stripThirdPartyFromAuthMessage(error.message);
  }
  if (error is FirebaseAuthException) {
    switch (error.code) {
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'بيانات الدخول غير صحيحة';
      case 'invalid-email':
        return 'البريد الإلكتروني غير صالح';
      case 'user-disabled':
        return 'هذا الحساب معطّل';
      case 'too-many-requests':
        return 'محاولات كثيرة. حاول لاحقاً';
      case 'network-request-failed':
        return 'تعذّر الاتصال. تحقّق من الشبكة';
      default:
        return 'تعذّر تسجيل الدخول. حاول مرة أخرى';
    }
  }
  return stripThirdPartyFromAuthMessage(error.toString());
}

bool forgotPasswordUseFirebaseClientFallback(DarbakException error) {
  final code = error.httpStatus;
  final message = error.message;
  if (code == 404 && message.contains('لا يوجد حساب')) return false;
  if (code == 404) return true;
  if (code == 502 || code == 503) return true;
  if (message == 'تعذّر إكمال الطلب.') return true;
  return false;
}
