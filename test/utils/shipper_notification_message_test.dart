import 'package:darbak/shipper_home.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normalizeContractNotificationMessage', () {
    test('strips contract number suffix', () {
      expect(
        normalizeContractNotificationMessage('تم إنشاء عقد رقم #42'),
        'تم إنشاء عقد',
      );
    });
  });

  group('replaceShipmentIdWithRoute', () {
    test('replaces shipment id token with route description', () {
      expect(
        replaceShipmentIdWithRoute('تم تعيين سائق للشحنة #15', 'الرياض → جدة'),
        'تم تعيين سائق للشحنة الرياض → جدة',
      );
      expect(
        replaceShipmentIdWithRoute('الشحنة رقم 9 في الطريق', 'جدة'),
        'الشحنة جدة في الطريق',
      );
    });

    test('returns original when route missing', () {
      const message = 'تنبيه للشحنة #3';
      expect(replaceShipmentIdWithRoute(message, null), message);
      expect(replaceShipmentIdWithRoute(message, ''), message);
    });
  });
}
