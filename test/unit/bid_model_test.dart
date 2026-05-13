import 'package:darbak/models/bid_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BidModel', () {
    test('fromJson parses all fields from API-shaped map', () {
      final m = BidModel.fromJson({
        'id': 12,
        'shipment_id': 3,
        'driver_id': 44,
        'bid_amount': 1500.5,
        'estimated_days': 7,
        'bid_status': 'pending',
        'driver_name': 'أحمد',
        'license_no': 'L1',
        'phone': '0512345678',
        'driver_rating': 4.5,
        'rating_count': 10,
      });
      expect(m.id, 12);
      expect(m.shipmentId, 3);
      expect(m.driverId, 44);
      expect(m.bidAmount, 1500.5);
      expect(m.estimatedDays, 7);
      expect(m.bidStatus, 'pending');
      expect(m.driverName, 'أحمد');
      expect(m.licenseNo, 'L1');
      expect(m.phone, '0512345678');
      expect(m.driverRating, 4.5);
      expect(m.ratingCount, 10);
    });

    test('driverName falls back to full_name when driver_name missing', () {
      final m = BidModel.fromJson({
        'id': 1,
        'shipment_id': 1,
        'driver_id': 1,
        'bid_amount': 100,
        'estimated_days': 2,
        'bid_status': 'pending',
        'full_name': 'محمد',
        'driver_rating': 0,
        'rating_count': 0,
      });
      expect(m.driverName, 'محمد');
    });

    test("driverName defaults to 'سائق' when driver_name and full_name missing", () {
      final m = BidModel.fromJson({
        'id': 1,
        'shipment_id': 1,
        'driver_id': 1,
        'bid_amount': 1,
        'estimated_days': 1,
        'bid_status': 'pending',
        'driver_rating': 0,
        'rating_count': 0,
      });
      expect(m.driverName, 'سائق');
    });

    test('invalid numeric fields default to 0 or 0.0', () {
      final m = BidModel.fromJson({
        'id': 'x',
        'shipment_id': '',
        'driver_id': null,
        'bid_amount': 'bad',
        'estimated_days': 'nope',
        'bid_status': 'pending',
        'driver_name': 'س',
        'driver_rating': 'xx',
        'rating_count': '?',
      });
      expect(m.id, 0);
      expect(m.shipmentId, 0);
      expect(m.driverId, 0);
      expect(m.bidAmount, 0.0);
      expect(m.estimatedDays, 0);
      expect(m.driverRating, 0.0);
      expect(m.ratingCount, 0);
    });

    test('toJson round-trip preserves values', () {
      final original = BidModel(
        id: 5,
        shipmentId: 9,
        driverId: 2,
        bidAmount: 888.25,
        estimatedDays: 14,
        bidStatus: 'accepted',
        driverName: 'خالد',
        licenseNo: 'Z9',
        phone: '0599999999',
        driverRating: 3.25,
        ratingCount: 4,
      );
      final json = original.toJson();
      final back = BidModel.fromJson(json);
      expect(back.id, original.id);
      expect(back.shipmentId, original.shipmentId);
      expect(back.driverId, original.driverId);
      expect(back.bidAmount, original.bidAmount);
      expect(back.estimatedDays, original.estimatedDays);
      expect(back.bidStatus, original.bidStatus);
      expect(back.driverName, original.driverName);
      expect(back.licenseNo, original.licenseNo);
      expect(back.phone, original.phone);
      expect(back.driverRating, original.driverRating);
      expect(back.ratingCount, original.ratingCount);
    });
  });
}
