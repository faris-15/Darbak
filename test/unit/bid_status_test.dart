import 'package:darbak/bid_status.dart';
import 'package:darbak/models/bid_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BidStatus.arabicLabel', () {
    test('maps pending, accepted, rejected, withdrawn', () {
      expect(BidStatus.arabicLabel('pending'), 'قيد المراجعة');
      expect(BidStatus.arabicLabel('accepted'), 'مقبول');
      expect(BidStatus.arabicLabel('rejected'), 'مرفوض');
      expect(BidStatus.arabicLabel('withdrawn'), 'مسحوب');
    });

    test('returns raw string for unknown status', () {
      expect(BidStatus.arabicLabel('custom'), 'custom');
    });
  });

  group('BidStatus.statusColor', () {
    test('maps core statuses', () {
      expect(BidStatus.statusColor('accepted'), Colors.green);
      expect(BidStatus.statusColor('rejected'), Colors.red);
      expect(BidStatus.statusColor('pending'), Colors.orange);
      expect(BidStatus.statusColor('withdrawn'), Colors.grey);
    });
  });

  group('BidStatus.canWithdrawBid', () {
    test('true only for pending', () {
      expect(BidStatus.canWithdrawBid('pending'), isTrue);
      expect(BidStatus.canWithdrawBid('accepted'), isFalse);
    });
  });

  group('BidStatus.canAcceptBid', () {
    test('true when pending and no accepted bid tracked', () {
      expect(BidStatus.canAcceptBid('pending', acceptedBidId: null), isTrue);
    });

    test('false when not pending or bid already accepted', () {
      expect(BidStatus.canAcceptBid('accepted', acceptedBidId: null), isFalse);
      expect(BidStatus.canAcceptBid('pending', acceptedBidId: 9), isFalse);
    });
  });

  group('BidStatus.isBidFinal', () {
    test('true for terminal statuses', () {
      expect(BidStatus.isBidFinal('accepted'), isTrue);
      expect(BidStatus.isBidFinal('rejected'), isTrue);
      expect(BidStatus.isBidFinal('withdrawn'), isTrue);
      expect(BidStatus.isBidFinal('pending'), isFalse);
    });
  });

  group('BidStatus.calculateLowestBid', () {
    test('empty list returns null', () {
      expect(BidStatus.calculateLowestBid([]), isNull);
    });

    test('single bid returns its amount', () {
      final bids = [
        _bid(amount: 500),
      ];
      expect(BidStatus.calculateLowestBid(bids), 500.0);
    });

    test('multiple bids returns minimum amount', () {
      final bids = [
        _bid(amount: 300),
        _bid(amount: 100),
        _bid(amount: 200),
      ];
      expect(BidStatus.calculateLowestBid(bids), 100.0);
    });
  });
}

BidModel _bid({required double amount}) {
  return BidModel(
    id: 1,
    shipmentId: 1,
    driverId: 1,
    bidAmount: amount,
    estimatedDays: 1,
    bidStatus: 'pending',
    driverName: 'سائق',
    driverRating: 0,
    ratingCount: 0,
  );
}
