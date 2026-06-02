/**
 * Tests for utils/lateDeliveryPenalty.js
 *
 * Business rules (see docstring in the module):
 *   - A grace period of `graceDays` (default 1) day starts AFTER the deadline.
 *     Day 2 past the deadline → 5%, +5% per day, capped at `capPercent` (25%),
 *     which is reached on day 6 past the deadline.
 *   - Returns 0 when price is non-positive / non-finite.
 *   - calendarDaysFrom uses LOCAL midnight, not absolute hours, so daylight-
 *     savings transitions cannot accidentally bump a penalty band.
 *
 * Edge cases tested:
 *   - exact deadline (0 days)
 *   - last day of grace (1 day)
 *   - first penalty day (2 days, expect 5%)
 *   - cap day and beyond
 *   - early delivery (negative days) -> 0
 *   - invalid deadline / asOfDate strings -> 0
 *   - non-numeric / negative prices -> 0
 *   - custom thresholds
 *   - shipmentDeadline picks final_delivery_date over expected_delivery_date
 */
'use strict';

const {
  startOfLocalDay,
  calendarDaysFrom,
  computeLatePenaltyFromDeadline,
  shipmentDeadline,
} = require('../../utils/lateDeliveryPenalty');

const day = (iso) => new Date(`${iso}T12:00:00`); // pin to midday-local to avoid DST flicker

describe('utils/lateDeliveryPenalty', () => {
  describe('startOfLocalDay', () => {
    test('zeroes hours/minutes/seconds', () => {
      const result = startOfLocalDay(new Date('2026-05-01T15:34:21'));
      expect(result.getHours()).toBe(0);
      expect(result.getMinutes()).toBe(0);
      expect(result.getSeconds()).toBe(0);
    });

    test('returns null for invalid input', () => {
      expect(startOfLocalDay('not-a-date')).toBeNull();
    });
  });

  describe('calendarDaysFrom', () => {
    test('returns 0 for the same day at different hours', () => {
      expect(
        calendarDaysFrom(
          new Date('2026-05-01T08:00:00'),
          new Date('2026-05-01T23:30:00')
        )
      ).toBe(0);
    });

    test('counts whole calendar days even across midnight', () => {
      expect(
        calendarDaysFrom(
          new Date('2026-05-01T23:59:00'),
          new Date('2026-05-02T00:01:00')
        )
      ).toBe(1);
    });

    test('returns negative when b is before a', () => {
      expect(
        calendarDaysFrom(new Date('2026-05-10T12:00:00'), new Date('2026-05-05T12:00:00'))
      ).toBe(-5);
    });

    test('returns 0 when one input is invalid', () => {
      expect(calendarDaysFrom('garbage', day('2026-05-01'))).toBe(0);
    });
  });

  describe('computeLatePenaltyFromDeadline', () => {
    const PRICE = 1000;

    test.each([
      ['delivered same day',     0,      0,  0],
      ['last day of grace',      1,      0,  0],
      ['day 2 -> 5%',            2,      5,  50],
      ['day 3 -> 10%',           3,      10, 100],
      ['cap reached on day 6',   6,      25, 250],
      ['far past cap stays 25%', 30,     25, 250],
      ['delivered 5 days early', -5,     0,  0],
    ])('%s', (_label, daysLate, expectedPercent, expectedAmount) => {
      const deadline = day('2026-06-01');
      const asOf = new Date(deadline.getTime() + daysLate * 86_400_000);
      const result = computeLatePenaltyFromDeadline(deadline, asOf, PRICE);
      expect(result.percent).toBe(expectedPercent);
      expect(result.amount).toBeCloseTo(expectedAmount, 2);
    });

    test('respects custom grace / daily / cap', () => {
      const deadline = day('2026-06-01');
      const asOf = day('2026-06-08'); // 7 days late
      const result = computeLatePenaltyFromDeadline(deadline, asOf, 200, {
        graceDays: 2,
        dailyPercent: 10,
        capPercent: 40,
      });
      // 7 - 2 grace = 5 days * 10% = 50%, capped at 40%
      expect(result.percent).toBe(40);
      expect(result.amount).toBeCloseTo(80, 2);
      expect(result.daysPastGrace).toBe(5);
    });

    test('returns 0 when price is non-positive', () => {
      expect(computeLatePenaltyFromDeadline(day('2026-06-01'), day('2026-07-01'), 0))
        .toEqual({ percent: 0, amount: 0, daysPastGrace: 0 });
      expect(computeLatePenaltyFromDeadline(day('2026-06-01'), day('2026-07-01'), -100))
        .toEqual({ percent: 0, amount: 0, daysPastGrace: 0 });
    });

    test('returns 0 when price is not a finite number', () => {
      expect(computeLatePenaltyFromDeadline(day('2026-06-01'), day('2026-07-01'), 'abc'))
        .toEqual({ percent: 0, amount: 0, daysPastGrace: 0 });
      expect(computeLatePenaltyFromDeadline(day('2026-06-01'), day('2026-07-01'), Infinity))
        .toEqual({ percent: 0, amount: 0, daysPastGrace: 0 });
    });

    test('rounds amount to 2 decimal places', () => {
      const result = computeLatePenaltyFromDeadline(
        day('2026-06-01'),
        day('2026-06-03'), // 2 days late => 5%
        333.33
      );
      expect(result.percent).toBe(5);
      expect(result.amount).toBe(16.67); // 333.33 * 5% = 16.6665 -> 16.67
    });
  });

  describe('shipmentDeadline', () => {
    test('prefers final_delivery_date over expected_delivery_date', () => {
      expect(
        shipmentDeadline({
          final_delivery_date: '2026-07-01',
          expected_delivery_date: '2026-06-15',
        })
      ).toBe('2026-07-01');
    });

    test('falls back to expected_delivery_date when final is missing', () => {
      expect(shipmentDeadline({ expected_delivery_date: '2026-06-15' })).toBe('2026-06-15');
    });

    test('returns null when both are absent', () => {
      expect(shipmentDeadline({})).toBeNull();
      expect(shipmentDeadline(null)).toBeNull();
    });
  });
});
