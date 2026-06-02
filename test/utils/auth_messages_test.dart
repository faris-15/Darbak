import 'package:darbak/api_service.dart';
import 'package:darbak/utils/auth_messages.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('stripThirdPartyFromAuthMessage', () {
    test('masks firebase/google/provider names', () {
      expect(
        stripThirdPartyFromAuthMessage('Firebase auth failed'),
        'تعذّر إكمال العملية. حاول مرة أخرى.',
      );
      expect(
        stripThirdPartyFromAuthMessage('خطأ من google'),
        'تعذّر إكمال العملية. حاول مرة أخرى.',
      );
      expect(
        stripThirdPartyFromAuthMessage('فايربيس غير متاح'),
        'تعذّر إكمال العملية. حاول مرة أخرى.',
      );
    });

    test('returns original message when clean', () {
      expect(stripThirdPartyFromAuthMessage('بيانات غير صحيحة'), 'بيانات غير صحيحة');
    });
  });

  group('userFacingForgotPasswordMessage', () {
    test('maps server 500 to retry message', () {
      expect(
        userFacingForgotPasswordMessage(
          DarbakException('server', httpStatus: 500),
        ),
        'تعذّر إرسال الرابط حالياً. حاول لاحقاً.',
      );
    });

    test('preserves explicit no-account message', () {
      expect(
        userFacingForgotPasswordMessage(
          DarbakException('لا يوجد حساب', httpStatus: 404),
        ),
        'لا يوجد حساب',
      );
    });

    test('maps socket errors to connectivity message', () {
      expect(
        userFacingForgotPasswordMessage(
          Exception('SocketException: connection refused'),
        ),
        'تعذّر الاتصال بالخادم',
      );
    });

    test('returns generic no-account for unknown errors', () {
      expect(
        userFacingForgotPasswordMessage(Exception('weird')),
        'لا يوجد حساب بهذا البريد الإلكتروني أو أنّه غير صحيح.',
      );
    });
  });

  group('firebaseLoginMessage', () {
    test('maps FirebaseAuthException codes', () {
      expect(
        firebaseLoginMessage(
          FirebaseAuthException(code: 'wrong-password'),
        ),
        'بيانات الدخول غير صحيحة',
      );
      expect(
        firebaseLoginMessage(
          FirebaseAuthException(code: 'invalid-email'),
        ),
        'البريد الإلكتروني غير صالح',
      );
      expect(
        firebaseLoginMessage(
          FirebaseAuthException(code: 'network-request-failed'),
        ),
        'تعذّر الاتصال. تحقّق من الشبكة',
      );
      expect(
        firebaseLoginMessage(FirebaseAuthException(code: 'unknown')),
        'تعذّر تسجيل الدخول. حاول مرة أخرى',
      );
    });
  });

  group('forgotPasswordUseFirebaseClientFallback', () {
    test('404 with no-account does not fallback', () {
      expect(
        forgotPasswordUseFirebaseClientFallback(
          DarbakException('لا يوجد حساب', httpStatus: 404),
        ),
        isFalse,
      );
    });

    test('404 without no-account triggers fallback', () {
      expect(
        forgotPasswordUseFirebaseClientFallback(
          DarbakException('not found', httpStatus: 404),
        ),
        isTrue,
      );
    });

    test('502/503 and generic completion error trigger fallback', () {
      expect(
        forgotPasswordUseFirebaseClientFallback(
          DarbakException('bad gateway', httpStatus: 502),
        ),
        isTrue,
      );
      expect(
        forgotPasswordUseFirebaseClientFallback(
          DarbakException('تعذّر إكمال الطلب.'),
        ),
        isTrue,
      );
    });
  });
}
