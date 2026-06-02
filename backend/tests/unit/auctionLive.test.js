/**
 * Tests for utils/auctionLive.js — a tiny but security-critical helper that
 * decides whether the auction window is still open. Even a 1-millisecond bug
 * here can let drivers bid past the deadline, so we cover **every** branch:
 *   - missing shipment / null input
 *   - empty / null auction_end_time -> false
 *   - invalid string -> false (no NaN propagation)
 *   - past timestamp -> false
 *   - exact `Date.now()` -> false (strict greater-than)
 *   - 1ms in the future -> true
 *   - far-future ISO and Date object -> true
 */
'use strict';

const { isShipmentAuctionStillLive } = require('../../utils/auctionLive');

describe('utils/auctionLive.isShipmentAuctionStillLive', () => {
  const FROZEN_NOW = new Date('2026-01-01T12:00:00Z').getTime();

  beforeEach(() => {
    jest.useFakeTimers().setSystemTime(FROZEN_NOW);
  });

  afterAll(() => {
    jest.useRealTimers();
  });

  test('returns false when shipment is null / undefined', () => {
    expect(isShipmentAuctionStillLive(null)).toBe(false);
    expect(isShipmentAuctionStillLive(undefined)).toBe(false);
  });

  test.each([
    ['null',         { auction_end_time: null }],
    ['empty string', { auction_end_time: '' }],
    ['undefined',    { auction_end_time: undefined }],
    ['garbage',      { auction_end_time: 'not-a-date' }],
  ])('returns false when auction_end_time is %s', (_label, shipment) => {
    expect(isShipmentAuctionStillLive(shipment)).toBe(false);
  });

  test('returns false when deadline is in the past', () => {
    const past = new Date(FROZEN_NOW - 60_000).toISOString();
    expect(isShipmentAuctionStillLive({ auction_end_time: past })).toBe(false);
  });

  test('returns false when deadline equals now (strict greater-than)', () => {
    const now = new Date(FROZEN_NOW).toISOString();
    expect(isShipmentAuctionStillLive({ auction_end_time: now })).toBe(false);
  });

  test('returns true when deadline is 1 ms in the future', () => {
    const just = new Date(FROZEN_NOW + 1).toISOString();
    expect(isShipmentAuctionStillLive({ auction_end_time: just })).toBe(true);
  });

  test('accepts Date objects and large futures', () => {
    expect(
      isShipmentAuctionStillLive({ auction_end_time: new Date(FROZEN_NOW + 86_400_000) })
    ).toBe(true);
  });

  test('accepts numeric epoch timestamps in the future', () => {
    expect(isShipmentAuctionStillLive({ auction_end_time: FROZEN_NOW + 5000 })).toBe(true);
  });
});
