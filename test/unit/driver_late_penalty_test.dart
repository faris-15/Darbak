import 'package:darbak/driver_home.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('latePenaltyBannerInfo', () {
    test('returns null for delivered shipments', () {
      expect(
        latePenaltyBannerInfo({
          'status': 'delivered',
          'expected_delivery_date':
              DateTime.now().subtract(const Duration(days: 20)).toIso8601String(),
          'accepted_bid_amount': 1000,
        }),
        isNull,
      );
    });

    test('returns null within grace period', () {
      expect(
        latePenaltyBannerInfo({
          'status': 'en_route',
          'expected_delivery_date':
              DateTime.now().subtract(const Duration(days: 3)).toIso8601String(),
          'accepted_bid_amount': 2000,
        }),
        isNull,
      );
    });

    test('computes tiered penalty after grace window', () {
      final info = latePenaltyBannerInfo({
        'status': 'en_route',
        'expected_delivery_date':
            DateTime.now().subtract(const Duration(days: 12)).toIso8601String(),
        'accepted_bid_amount': 1000,
      });
      expect(info, isNotNull);
      expect(info!['percent'], greaterThan(0));
      expect(info['amount'], greaterThan(0));
    });

    test('uses server-provided penalty when present', () {
      final info = latePenaltyBannerInfo({
        'status': 'assigned',
        'expected_delivery_date': '2026-01-01T00:00:00Z',
        'accepted_bid_amount': 1000,
        'late_penalty_percent': 15,
        'late_penalty_amount': 150,
      });
      expect(info, {'percent': 15, 'amount': 150.0});
    });
  });
}
