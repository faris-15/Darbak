import 'package:flutter_test/flutter_test.dart';
import 'package:darbak/models/bid_model.dart';

void main() {
  group('BidModel.fromJson', () {
    test('parses canonical API payload', () {
      final bid = BidModel.fromJson({
        'id': '10',
        'shipment_id': '20',
        'driver_id': '30',
        'bid_amount': '1450.75',
        'estimated_days': '3',
        'bid_status': 'pending',
        'driver_name': 'سائق',
        'license_no': 'L-123',
        'phone': '0500000000',
        'driver_rating': '4.5',
        'rating_count': '8',
      });

      expect(bid.id, 10);
      expect(bid.shipmentId, 20);
      expect(bid.driverId, 30);
      expect(bid.bidAmount, 1450.75);
      expect(bid.estimatedDays, 3);
      expect(bid.driverName, 'سائق');
      expect(bid.driverRating, 4.5);
      expect(bid.ratingCount, 8);
    });

    test('falls back to full_name and safe numeric defaults', () {
      final bid = BidModel.fromJson({
        'id': 'bad',
        'full_name': 'بديل',
        'driver_rating': '-1',
      });

      expect(bid.id, 0);
      expect(bid.bidAmount, 0);
      expect(bid.estimatedDays, 0);
      expect(bid.driverName, 'بديل');
      expect(bid.driverRating, isNull);
      expect(bid.ratingCount, 0);
    });

    test('clamps over-range rating to five', () {
      final bid = BidModel.fromJson({'driver_rating': 99});
      expect(bid.driverRating, 5);
    });
  });

  test('toJson keeps backend snake_case contract', () {
    final bid = BidModel(
      id: 1,
      shipmentId: 2,
      driverId: 3,
      bidAmount: 4,
      estimatedDays: 5,
      bidStatus: 'accepted',
      driverName: 'سائق',
      driverRating: 4.2,
      ratingCount: 9,
    );

    expect(bid.toJson(), {
      'id': 1,
      'shipment_id': 2,
      'driver_id': 3,
      'bid_amount': 4.0,
      'estimated_days': 5,
      'bid_status': 'accepted',
      'driver_name': 'سائق',
      'license_no': null,
      'phone': null,
      'driver_rating': 4.2,
      'rating_count': 9,
    });
  });
}
