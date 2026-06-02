/**
 * Integration tests for /api/bidding-rooms/* (biddingRoomController +
 * biddingRoomRoutes + Bid model). The controller mixes Bid model methods
 * with direct pool.execute() calls so we drive both through dbMock.
 */
'use strict';

const request = require('supertest');

const { buildTestApp } = require('../helpers/testApp');
const { dbMock } = require('../helpers/db');
const { shipmentFactory } = require('../helpers/factories');

const app = () => buildTestApp({ routes: ['biddingRooms'] });

const expectExpireSweep = () =>
  dbMock.expectUpdate(/UPDATE bids b\s+INNER JOIN shipments s/i).returnsAffected(0);

const expectFindShipment = (row) =>
  dbMock.expectSelect(/FROM shipments s\s+LEFT JOIN users sh/i).returns(row ? [row] : []);

const expectExistingBids = (rows = []) =>
  dbMock
    .expectSelect(/FROM bids WHERE shipment_id = \? AND driver_id = \? AND bid_status = \?/i)
    .returns(rows);

const expectOtherRoom = (row = null) =>
  dbMock
    .expectSelect(/FROM bids b\s+INNER JOIN shipments s/i)
    .returns(row ? [row] : []);

const expectRoomStatus = (rows = []) =>
  dbMock
    .expectSelect(/FROM bids WHERE shipment_id = \? AND bid_status = \? ORDER BY bid_amount ASC$/i)
    .returns(rows);

const expectLowestPending = (row = null) =>
  dbMock
    .expectSelect(/FROM bids WHERE shipment_id = \? AND bid_status = \? ORDER BY bid_amount ASC LIMIT 1/i)
    .returns(row ? [row] : []);

describe('POST /api/bidding-rooms/rooms/:shipmentId/enter', () => {
  test('400 when body fields missing', async () => {
    expectExpireSweep();
    const res = await request(app())
      .post('/api/bidding-rooms/rooms/1000/enter')
      .send({});
    expect(res.status).toBe(400);
  });

  test('404 when shipment missing', async () => {
    expectExpireSweep();
    expectFindShipment(null);
    const res = await request(app())
      .post('/api/bidding-rooms/rooms/1000/enter')
      .send({ driverId: 100, bidAmount: 1500, estimatedDays: 2 });
    expect(res.status).toBe(404);
  });

  test('400 when shipment is not bidding', async () => {
    expectExpireSweep();
    expectFindShipment(shipmentFactory({ status: 'delivered' }));
    const res = await request(app())
      .post('/api/bidding-rooms/rooms/1000/enter')
      .send({ driverId: 100, bidAmount: 1500, estimatedDays: 2 });
    expect(res.status).toBe(400);
    expect(res.body.message).toMatch(/لا تقبل/);
  });

  test('400 when auction has ended', async () => {
    expectExpireSweep();
    expectFindShipment(
      shipmentFactory({
        status: 'bidding',
        auction_end_time: new Date(Date.now() - 60_000).toISOString(),
      })
    );
    const res = await request(app())
      .post('/api/bidding-rooms/rooms/1000/enter')
      .send({ driverId: 100, bidAmount: 1500, estimatedDays: 2 });
    expect(res.status).toBe(400);
    expect(res.body.message).toMatch(/انتهى وقت/);
  });

  test('400 when driver already has a pending bid for this shipment', async () => {
    expectExpireSweep();
    expectFindShipment(shipmentFactory({ status: 'bidding' }));
    expectExistingBids([{ id: 5, bid_amount: 1500 }]);
    const res = await request(app())
      .post('/api/bidding-rooms/rooms/1000/enter')
      .send({ driverId: 100, bidAmount: 1500, estimatedDays: 2 });
    expect(res.status).toBe(400);
    expect(res.body.message).toMatch(/معلق/);
  });

  test('409 when driver participates in another auction', async () => {
    expectExpireSweep();
    expectFindShipment(shipmentFactory({ status: 'bidding' }));
    expectExistingBids([]);
    expectOtherRoom({ bid_id: 7777, shipment_id: 2000 });
    const res = await request(app())
      .post('/api/bidding-rooms/rooms/1000/enter')
      .send({ driverId: 100, bidAmount: 1500, estimatedDays: 2 });
    expect(res.status).toBe(409);
    expect(res.body.code).toBe('SINGLE_BID_ROOM');
  });

  test('200 places a bid and returns room status', async () => {
    expectExpireSweep();
    expectFindShipment(shipmentFactory({ status: 'bidding' }));
    expectExistingBids([]);
    expectOtherRoom(null);
    dbMock.expectInsert(/INSERT INTO bids/i).returnsInsert(7000);
    expectRoomStatus([
      { id: 7000, driver_id: 100, bid_amount: 1500, estimated_days: 2 },
    ]);

    const res = await request(app())
      .post('/api/bidding-rooms/rooms/1000/enter')
      .send({ driverId: 100, bidAmount: '1500', estimatedDays: '2' });
    expect(res.status).toBe(200);
    expect(res.body.room).toMatchObject({
      shipment_id: '1000',
      total_bids: 1,
      room_status: 'open',
      lowest_bid: { id: 7000, driver_id: 100, bid_amount: 1500, estimated_days: 2 },
    });
  });

  test('500 when bid insert fails', async () => {
    expectExpireSweep();
    expectFindShipment(shipmentFactory({ status: 'bidding' }));
    expectExistingBids([]);
    expectOtherRoom(null);
    dbMock.expectInsert(/INSERT INTO bids/i).rejectsWith(new Error('boom'));
    const res = await request(app())
      .post('/api/bidding-rooms/rooms/1000/enter')
      .send({ driverId: 100, bidAmount: 1500, estimatedDays: 2 });
    expect(res.status).toBe(500);
  });
});

describe('POST /api/bidding-rooms/rooms/:shipmentId/exit', () => {
  test('404 when driver has no pending bid', async () => {
    expectExpireSweep();
    expectFindShipment(shipmentFactory({ status: 'bidding' }));
    expectExistingBids([]);
    const res = await request(app())
      .post('/api/bidding-rooms/rooms/1000/exit')
      .send({ driverId: 100 });
    expect(res.status).toBe(404);
  });

  test('403 when driver is current lowest bidder during live auction', async () => {
    expectExpireSweep();
    expectFindShipment(
      shipmentFactory({
        status: 'bidding',
        auction_end_time: new Date(Date.now() + 60_000).toISOString(),
      })
    );
    expectExistingBids([{ id: 5, driver_id: 100, bid_amount: 1500 }]);
    expectLowestPending({ driver_id: 100, bid_amount: 1500 });
    const res = await request(app())
      .post('/api/bidding-rooms/rooms/1000/exit')
      .send({ driverId: 100 });
    expect(res.status).toBe(403);
    expect(res.body.message).toMatch(/الفائز/);
  });

  test('200 cancels bid when auction is closed or not lowest', async () => {
    expectExpireSweep();
    expectFindShipment(shipmentFactory({ status: 'bidding', auction_end_time: null }));
    expectExistingBids([{ id: 5, driver_id: 100, bid_amount: 1500 }]);
    expectLowestPending({ driver_id: 999, bid_amount: 1000 });
    dbMock.expectUpdate(/UPDATE bids SET bid_status = \? WHERE id = \?/i).returnsAffected(1);
    expectRoomStatus([]);
    const res = await request(app())
      .post('/api/bidding-rooms/rooms/1000/exit')
      .send({ driverId: 100 });
    expect(res.status).toBe(200);
    expect(res.body.room.room_status).toBe('empty');
  });

  test('500 when Bid.setStatus reports no rows', async () => {
    expectExpireSweep();
    expectFindShipment(shipmentFactory({ status: 'bidding', auction_end_time: null }));
    expectExistingBids([{ id: 5, driver_id: 100, bid_amount: 1500 }]);
    expectLowestPending(null);
    dbMock.expectUpdate(/UPDATE bids SET bid_status = \? WHERE id = \?/i).returnsAffected(0);
    const res = await request(app())
      .post('/api/bidding-rooms/rooms/1000/exit')
      .send({ driverId: 100 });
    expect(res.status).toBe(500);
  });
});

describe('GET /api/bidding-rooms/rooms/:shipmentId/status', () => {
  test('404 when shipment missing', async () => {
    expectFindShipment(null);
    const res = await request(app()).get('/api/bidding-rooms/rooms/1000/status');
    expect(res.status).toBe(404);
  });

  test('200 returns room status with the lowest bid first', async () => {
    expectFindShipment(shipmentFactory({ status: 'bidding' }));
    expectRoomStatus([
      { id: 1, driver_id: 100, bid_amount: 1500, estimated_days: 2 },
      { id: 2, driver_id: 200, bid_amount: 1800, estimated_days: 3 },
    ]);
    const res = await request(app()).get('/api/bidding-rooms/rooms/1000/status');
    expect(res.status).toBe(200);
    expect(res.body.total_bids).toBe(2);
    expect(res.body.lowest_bid.id).toBe(1);
  });

  test('500 when room aggregation throws', async () => {
    expectFindShipment(shipmentFactory({ status: 'bidding' }));
    dbMock
      .expectSelect(/FROM bids WHERE shipment_id = \? AND bid_status = \? ORDER BY bid_amount ASC$/i)
      .rejectsWith(new Error('boom'));
    const res = await request(app()).get('/api/bidding-rooms/rooms/1000/status');
    expect(res.status).toBe(500);
  });
});
