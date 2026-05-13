import 'package:darbak/darbak_input_validation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DarbakInputValidation.isValidEmail', () {
    test('accepts typical email', () {
      expect(DarbakInputValidation.isValidEmail('user@example.com'), isTrue);
    });

    test('rejects empty and invalid', () {
      expect(DarbakInputValidation.isValidEmail(''), isFalse);
      expect(DarbakInputValidation.isValidEmail('not-an-email'), isFalse);
    });

    test('rejects null and only-whitespace', () {
      expect(DarbakInputValidation.isValidEmail(null), isFalse);
      expect(DarbakInputValidation.isValidEmail('   '), isFalse);
    });

    test('rejects missing at-sign', () {
      expect(DarbakInputValidation.isValidEmail('user.example.com'), isFalse);
      expect(DarbakInputValidation.isValidEmail('userexample.com'), isFalse);
    });

    test('rejects missing domain or missing local-part', () {
      expect(DarbakInputValidation.isValidEmail('user@'), isFalse);
      expect(DarbakInputValidation.isValidEmail('@example.com'), isFalse);
    });

    test('rejects spaces inside email', () {
      expect(DarbakInputValidation.isValidEmail('user @example.com'), isFalse);
      expect(DarbakInputValidation.isValidEmail('user@exa mple.com'), isFalse);
    });

    test('accepts uppercase and trims around value', () {
      expect(DarbakInputValidation.isValidEmail('USER@EXAMPLE.COM'), isTrue);
      expect(DarbakInputValidation.isValidEmail('  user@example.com  '), isTrue);
    });

    test('accepts long but valid email', () {
      final longLocal = List.filled(60, 'a').join();
      final longDomain = List.filled(40, 'b').join();
      expect(
        DarbakInputValidation.isValidEmail('$longLocal@$longDomain.com'),
        isTrue,
      );
    });

    test('rejects sql-injection-like payloads', () {
      expect(
        DarbakInputValidation.isValidEmail("' OR 1=1 --@example.com"),
        isFalse,
      );
      expect(
        DarbakInputValidation.isValidEmail("admin'--@mail.com"),
        isFalse,
      );
    });
  });

  group('DarbakInputValidation.isValidSaudiPhone', () {
    test('accepts 05 + 8 digits', () {
      expect(DarbakInputValidation.isValidSaudiPhone('0512345678'), isTrue);
    });

    test('rejects wrong length or prefix', () {
      expect(DarbakInputValidation.isValidSaudiPhone('0412345678'), isFalse);
      expect(DarbakInputValidation.isValidSaudiPhone('051234567'), isFalse);
    });

    test('accepts internal spaces because validator strips whitespace', () {
      expect(DarbakInputValidation.isValidSaudiPhone('05 1234 5678'), isTrue);
      expect(DarbakInputValidation.isValidSaudiPhone(' 05 12345678 '), isTrue);
    });

    test('rejects null empty and only-spaces', () {
      expect(DarbakInputValidation.isValidSaudiPhone(null), isFalse);
      expect(DarbakInputValidation.isValidSaudiPhone(''), isFalse);
      expect(DarbakInputValidation.isValidSaudiPhone('   '), isFalse);
    });

    test('rejects too short boundary and too long boundary', () {
      expect(DarbakInputValidation.isValidSaudiPhone('051234567'), isFalse);
      expect(DarbakInputValidation.isValidSaudiPhone('05123456789'), isFalse);
    });

    test('rejects non-digit and punctuation characters', () {
      expect(DarbakInputValidation.isValidSaudiPhone('05abcdef12'), isFalse);
      expect(DarbakInputValidation.isValidSaudiPhone('05-1234-5678'), isFalse);
      expect(DarbakInputValidation.isValidSaudiPhone('05_12345678'), isFalse);
    });

    test('rejects wrong prefix variants', () {
      expect(DarbakInputValidation.isValidSaudiPhone('0612345678'), isFalse);
      expect(DarbakInputValidation.isValidSaudiPhone('9512345678'), isFalse);
      expect(DarbakInputValidation.isValidSaudiPhone('5012345678'), isFalse);
    });
  });

  group('DarbakInputValidation.isPasswordLongEnough', () {
    test('matches registration rule: minimum 6 characters', () {
      expect(DarbakInputValidation.isPasswordLongEnough('12345'), isFalse);
      expect(DarbakInputValidation.isPasswordLongEnough('123456'), isTrue);
    });

    test('rejects null and empty', () {
      expect(DarbakInputValidation.isPasswordLongEnough(null), isFalse);
      expect(DarbakInputValidation.isPasswordLongEnough(''), isFalse);
    });

    test('boundary values around min length', () {
      expect(DarbakInputValidation.isPasswordLongEnough('1234'), isFalse);
      expect(DarbakInputValidation.isPasswordLongEnough('12345'), isFalse);
      expect(DarbakInputValidation.isPasswordLongEnough('123456'), isTrue);
      expect(DarbakInputValidation.isPasswordLongEnough('1234567'), isTrue);
    });

    test('supports custom minimum length boundary', () {
      expect(
        DarbakInputValidation.isPasswordLongEnough('1234567', minLength: 8),
        isFalse,
      );
      expect(
        DarbakInputValidation.isPasswordLongEnough('12345678', minLength: 8),
        isTrue,
      );
    });

    test('accepts very long passwords', () {
      final veryLong = List.filled(512, 'x').join();
      expect(DarbakInputValidation.isPasswordLongEnough(veryLong), isTrue);
    });
  });

  group('DarbakInputValidation.isPositiveBidAmount', () {
    test('accepts positive numbers', () {
      expect(DarbakInputValidation.isPositiveBidAmount('100.5'), isTrue);
    });

    test('rejects non-positive', () {
      expect(DarbakInputValidation.isPositiveBidAmount('0'), isFalse);
      expect(DarbakInputValidation.isPositiveBidAmount('-1'), isFalse);
      expect(DarbakInputValidation.isPositiveBidAmount('x'), isFalse);
    });

    test('accepts decimal and trimmed values', () {
      expect(DarbakInputValidation.isPositiveBidAmount('0.01'), isTrue);
      expect(DarbakInputValidation.isPositiveBidAmount(' 12.75 '), isTrue);
    });

    test('rejects null empty and whitespace', () {
      expect(DarbakInputValidation.isPositiveBidAmount(null), isFalse);
      expect(DarbakInputValidation.isPositiveBidAmount(''), isFalse);
      expect(DarbakInputValidation.isPositiveBidAmount('   '), isFalse);
    });
  });

  group('DarbakInputValidation.isEstimatedDaysInRange', () {
    test('accepts 1–365', () {
      expect(DarbakInputValidation.isEstimatedDaysInRange(1), isTrue);
      expect(DarbakInputValidation.isEstimatedDaysInRange(365), isTrue);
      expect(DarbakInputValidation.isEstimatedDaysInRange(100), isTrue);
    });

    test('rejects outside range', () {
      expect(DarbakInputValidation.isEstimatedDaysInRange(0), isFalse);
      expect(DarbakInputValidation.isEstimatedDaysInRange(366), isFalse);
      expect(DarbakInputValidation.isEstimatedDaysInRange(null), isFalse);
    });

    test('supports custom min and max boundaries', () {
      expect(
        DarbakInputValidation.isEstimatedDaysInRange(4, min: 5, max: 10),
        isFalse,
      );
      expect(
        DarbakInputValidation.isEstimatedDaysInRange(5, min: 5, max: 10),
        isTrue,
      );
      expect(
        DarbakInputValidation.isEstimatedDaysInRange(10, min: 5, max: 10),
        isTrue,
      );
      expect(
        DarbakInputValidation.isEstimatedDaysInRange(11, min: 5, max: 10),
        isFalse,
      );
    });
  });

  group('DarbakInputValidation.isPositiveWeightTonnes', () {
    test('accepts positive weight', () {
      expect(DarbakInputValidation.isPositiveWeightTonnes('2.5'), isTrue);
    });

    test('rejects non-positive', () {
      expect(DarbakInputValidation.isPositiveWeightTonnes('0'), isFalse);
      expect(DarbakInputValidation.isPositiveWeightTonnes(''), isFalse);
    });

    test('accepts positive trimmed decimal', () {
      expect(DarbakInputValidation.isPositiveWeightTonnes(' 0.5 '), isTrue);
      expect(DarbakInputValidation.isPositiveWeightTonnes('99'), isTrue);
    });

    test('rejects null negatives and non-number', () {
      expect(DarbakInputValidation.isPositiveWeightTonnes(null), isFalse);
      expect(DarbakInputValidation.isPositiveWeightTonnes('-0.5'), isFalse);
      expect(DarbakInputValidation.isPositiveWeightTonnes('abc'), isFalse);
    });
  });

  group('DarbakInputValidation.isFullNameLongEnough', () {
    test('requires at least 3 characters trimmed', () {
      expect(DarbakInputValidation.isFullNameLongEnough('أب'), isFalse);
      expect(DarbakInputValidation.isFullNameLongEnough('أبج'), isTrue);
    });

    test('rejects null and whitespace-only names', () {
      expect(DarbakInputValidation.isFullNameLongEnough(null), isFalse);
      expect(DarbakInputValidation.isFullNameLongEnough('   '), isFalse);
    });

    test('custom min chars boundaries respected', () {
      expect(
        DarbakInputValidation.isFullNameLongEnough('John', minChars: 5),
        isFalse,
      );
      expect(
        DarbakInputValidation.isFullNameLongEnough('John D', minChars: 5),
        isTrue,
      );
    });
  });

  group('DarbakInputValidation registration document rules', () {
    test('isAllowedRegistrationDocumentExtension matches registration FilePicker', () {
      expect(DarbakInputValidation.isAllowedRegistrationDocumentExtension('doc.pdf'), isTrue);
      expect(DarbakInputValidation.isAllowedRegistrationDocumentExtension('x.PNG'), isTrue);
      expect(DarbakInputValidation.isAllowedRegistrationDocumentExtension('a.exe'), isFalse);
    });

    test('isAllowedRegistrationDocumentExtension handles edge paths and malformed names', () {
      expect(
        DarbakInputValidation.isAllowedRegistrationDocumentExtension(
          '/tmp/contracts/company.registration.v1.PDF',
        ),
        isTrue,
      );
      expect(DarbakInputValidation.isAllowedRegistrationDocumentExtension('noext'), isFalse);
      expect(DarbakInputValidation.isAllowedRegistrationDocumentExtension('.hiddenfile'), isFalse);
      expect(DarbakInputValidation.isAllowedRegistrationDocumentExtension('file.'), isFalse);
      expect(DarbakInputValidation.isAllowedRegistrationDocumentExtension(null), isFalse);
      expect(DarbakInputValidation.isAllowedRegistrationDocumentExtension(''), isFalse);
    });

    test('isFileWithinMaxBytes enforces positive size and cap', () {
      expect(DarbakInputValidation.isFileWithinMaxBytes(null), isFalse);
      expect(DarbakInputValidation.isFileWithinMaxBytes(0), isFalse);
      expect(DarbakInputValidation.isFileWithinMaxBytes(1024), isTrue);
      expect(
        DarbakInputValidation.isFileWithinMaxBytes(11 * 1024 * 1024, maxBytes: 10 * 1024 * 1024),
        isFalse,
      );
    });

    test('isFileWithinMaxBytes boundary values at configured max', () {
      const max = 10 * 1024;
      expect(DarbakInputValidation.isFileWithinMaxBytes(1, maxBytes: max), isTrue);
      expect(DarbakInputValidation.isFileWithinMaxBytes(max, maxBytes: max), isTrue);
      expect(DarbakInputValidation.isFileWithinMaxBytes(max + 1, maxBytes: max), isFalse);
      expect(DarbakInputValidation.isFileWithinMaxBytes(-1, maxBytes: max), isFalse);
    });
  });
}
