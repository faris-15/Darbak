import 'package:flutter_test/flutter_test.dart';
import 'package:darbak/utils/shipment_display.dart';

void main() {
  group('shipment lifecycle labels', () {
    test('maps known statuses to Arabic labels', () {
      expect(shipmentLifecycleStatusAr('pending'), 'قيد الانتظار');
      expect(shipmentLifecycleStatusAr('delivered'), 'تم التسليم بنجاح');
    });

    test('handles empty and unknown statuses', () {
      expect(shipmentLifecycleStatusAr(null), 'قيد المعالجة');
      expect(shipmentLifecycleStatusAr('  '), 'قيد المعالجة');
      expect(shipmentLifecycleStatusAr('lost'), 'حالة غير معروفة');
    });
  });

  group('address helpers', () {
    test('extracts city segment from comma-separated addresses', () {
      expect(shipmentCitySegment('الرياض, حي النرجس'), 'الرياض');
      expect(shipmentCitySegment(' جدة '), 'جدة');
      expect(shipmentCitySegment(null), 'غير محدد');
    });

    test('truncates primary line when needed', () {
      final value = shipmentAddressPrimaryLine(
        'أ'.padRight(80, 'ب'),
        maxChars: 10,
      );
      expect(value.length, 11);
      expect(value.endsWith('…'), isTrue);
    });

    test('builds legacy route title', () {
      expect(
        shipmentRouteTitle({
          'pickup_address': 'الرياض, السعودية',
          'dropoff_address': 'جدة, السعودية',
        }),
        'الرياض ➔ جدة',
      );
    });
  });

  group('shipper/company display', () {
    test('prefers top-level shipper name keys', () {
      expect(shipmentShipperDisplayName({'shipper_name': 'شركة ألف'}), 'شركة ألف');
    });

    test('falls back to nested shipper map', () {
      expect(
        shipmentShipperDisplayName({
          'shipper': {'companyName': 'شركة باء'},
        }),
        'شركة باء',
      );
    });

    test('returns localized company line fallback when missing', () {
      expect(shipmentCompanyUiLine({}), 'الشركة: غير متوفرة');
      expect(
        shipmentCompanyUiLine({'company_name': 'دربك'}),
        'الشركة: دربك',
      );
    });
  });

  test('shipmentAgreedPriceValue chooses accepted, suggested, then base price', () {
    expect(
      shipmentAgreedPriceValue({
        'accepted_bid_amount': 100,
        'suggested_price': 200,
        'base_price': 300,
      }),
      100,
    );
    expect(shipmentAgreedPriceValue({'suggested_price': 200, 'base_price': 300}), 200);
    expect(shipmentAgreedPriceValue({'base_price': 300}), 300);
  });

  test('formatShipmentDateTimeForUi handles invalid values gracefully', () {
    expect(formatShipmentDateTimeForUi(null), 'لم يتم تحديده');
    expect(formatShipmentDateTimeForUi('not-a-date'), 'لم يتم تحديده');
    expect(formatShipmentDateTimeForUi('2026-05-25T10:30:00Z'), isNotEmpty);
  });
}
