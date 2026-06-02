/**
 * Unit tests for the BiddingRoom model. Exercises every CRUD/lifecycle
 * helper, including the "single active bidding" invariant enforced in
 * enterRoom/exitRoom.
 */
'use strict';

const BiddingRoom = require('../../models/BiddingRoom');
const { dbMock } = require('../helpers/db');

describe('BiddingRoom.create', () => {
  test('returns hydrated room shape', async () => {
    dbMock.expectInsert(/INSERT INTO bids \(shipment_id\) VALUES \(\?\)/i).returnsInsert(11);
    const r = await BiddingRoom.create(1000);
    expect(r).toEqual({
      id: 11,
      shipment_id: 1000,
      active_driver_id: null,
      lowest_bidder_id: null,
      lowest_bid_amount: null,
      room_status: 'open',
    });
  });

  test('rethrows on DB error', async () => {
    dbMock
      .expectInsert(/INSERT INTO bids/i)
      .rejectsWith(new Error('dup'));
    await expect(BiddingRoom.create(1000)).rejects.toThrow('dup');
  });
});

describe('BiddingRoom.findByShipmentId and findById', () => {
  test('findByShipmentId returns first row', async () => {
    dbMock
      .expectSelect(/SELECT \* FROM bids WHERE shipment_id = \?/i)
      .returns([{ id: 1 }]);
    expect(await BiddingRoom.findByShipmentId(1000)).toEqual({ id: 1 });
  });

  test('findById returns row', async () => {
    dbMock
      .expectSelect(/SELECT \* FROM bids WHERE id = \?/i)
      .returns([{ id: 5 }]);
    expect(await BiddingRoom.findById(5)).toEqual({ id: 5 });
  });

  test('findByShipmentId rethrows', async () => {
    dbMock
      .expectSelect(/FROM bids WHERE shipment_id = \?/i)
      .rejectsWith(new Error('x'));
    await expect(BiddingRoom.findByShipmentId(1)).rejects.toThrow('x');
  });

  test('findById rethrows', async () => {
    dbMock
      .expectSelect(/FROM bids WHERE id = \?/i)
      .rejectsWith(new Error('x'));
    await expect(BiddingRoom.findById(1)).rejects.toThrow('x');
  });
});

describe('BiddingRoom.enterRoom', () => {
  test('throws when driver already active in another room', async () => {
    dbMock
      .expectSelect(/FROM bids WHERE driver_id = \? AND \(bid_status = "pending" OR bid_status = "locked"\)/i)
      .returns([{ id: 1 }]);
    await expect(BiddingRoom.enterRoom(1000, 100)).rejects.toThrow(/already active/);
  });

  test('returns true when driver enters', async () => {
    dbMock
      .expectSelect(/FROM bids WHERE driver_id = \?/i)
      .returns([]);
    dbMock
      .expectUpdate(/UPDATE bids SET driver_id = \? WHERE shipment_id = \? AND driver_id IS NULL/i)
      .returnsAffected(1);
    expect(await BiddingRoom.enterRoom(1000, 100)).toBe(true);
  });

  test('returns false when room is full', async () => {
    dbMock
      .expectSelect(/FROM bids WHERE driver_id = \?/i)
      .returns([]);
    dbMock
      .expectUpdate(/UPDATE bids SET driver_id = \?/i)
      .returnsAffected(0);
    expect(await BiddingRoom.enterRoom(1000, 100)).toBe(false);
  });

  test('rethrows on DB error', async () => {
    dbMock
      .expectSelect(/FROM bids WHERE driver_id = \?/i)
      .rejectsWith(new Error('boom'));
    await expect(BiddingRoom.enterRoom(1, 1)).rejects.toThrow('boom');
  });
});

describe('BiddingRoom.exitRoom', () => {
  test('throws when room not found', async () => {
    dbMock
      .expectSelect(/FROM bids WHERE shipment_id = \?/i)
      .returns([]);
    await expect(BiddingRoom.exitRoom(1, 1)).rejects.toThrow('Room not found');
  });

  test('throws when driver is the lowest bidder', async () => {
    dbMock
      .expectSelect(/FROM bids WHERE shipment_id = \?/i)
      .returns([{ id: 1, lowest_bidder_id: 100 }]);
    await expect(BiddingRoom.exitRoom(1000, 100)).rejects.toThrow(/lowest bidder/);
  });

  test('returns true when driver leaves', async () => {
    dbMock
      .expectSelect(/FROM bids WHERE shipment_id = \?/i)
      .returns([{ id: 1, lowest_bidder_id: 999 }]);
    dbMock
      .expectUpdate(/UPDATE bids SET driver_id = NULL WHERE shipment_id = \? AND driver_id = \?/i)
      .returnsAffected(1);
    expect(await BiddingRoom.exitRoom(1000, 100)).toBe(true);
  });

  test('rethrows on DB error', async () => {
    dbMock
      .expectSelect(/FROM bids WHERE shipment_id = \?/i)
      .returns([{ id: 1, lowest_bidder_id: 999 }]);
    dbMock
      .expectUpdate(/UPDATE bids SET driver_id = NULL/i)
      .rejectsWith(new Error('x'));
    await expect(BiddingRoom.exitRoom(1, 1)).rejects.toThrow('x');
  });
});

describe('BiddingRoom.updateLowestBid / closeRoom / lockRoom / getActiveRoomsForDriver', () => {
  test('updateLowestBid returns true', async () => {
    dbMock
      .expectUpdate(/UPDATE bids SET lowest_bidder_id = \?, lowest_bid_amount = \?/i)
      .returnsAffected(1);
    expect(await BiddingRoom.updateLowestBid(1000, 100, 1450)).toBe(true);
  });

  test('updateLowestBid rethrows', async () => {
    dbMock
      .expectUpdate(/UPDATE bids SET lowest_bidder_id/i)
      .rejectsWith(new Error('x'));
    await expect(BiddingRoom.updateLowestBid(1, 1, 1)).rejects.toThrow('x');
  });

  test('closeRoom marks shipment-room closed', async () => {
    dbMock
      .expectUpdate(/UPDATE bids SET bid_status = "closed" WHERE shipment_id = \?/i)
      .returnsAffected(1);
    expect(await BiddingRoom.closeRoom(1000)).toBe(true);
  });

  test('closeRoom rethrows', async () => {
    dbMock
      .expectUpdate(/UPDATE bids SET bid_status = "closed"/i)
      .rejectsWith(new Error('x'));
    await expect(BiddingRoom.closeRoom(1)).rejects.toThrow('x');
  });

  test('lockRoom marks shipment-room locked', async () => {
    dbMock
      .expectUpdate(/UPDATE bids SET bid_status = "locked" WHERE shipment_id = \?/i)
      .returnsAffected(1);
    expect(await BiddingRoom.lockRoom(1000)).toBe(true);
  });

  test('lockRoom rethrows', async () => {
    dbMock
      .expectUpdate(/UPDATE bids SET bid_status = "locked"/i)
      .rejectsWith(new Error('x'));
    await expect(BiddingRoom.lockRoom(1)).rejects.toThrow('x');
  });

  test('getActiveRoomsForDriver returns array', async () => {
    dbMock
      .expectSelect(/FROM bids WHERE driver_id = \? AND bid_status IN/i)
      .returns([{ id: 1 }, { id: 2 }]);
    expect(await BiddingRoom.getActiveRoomsForDriver(100)).toHaveLength(2);
  });

  test('getActiveRoomsForDriver rethrows', async () => {
    dbMock
      .expectSelect(/FROM bids WHERE driver_id = \? AND bid_status IN/i)
      .rejectsWith(new Error('x'));
    await expect(BiddingRoom.getActiveRoomsForDriver(1)).rejects.toThrow('x');
  });
});
