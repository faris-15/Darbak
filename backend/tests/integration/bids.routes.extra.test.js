/**
 * Additional integration tests for /api/bids covering the full
 * bidController surface (createBid, getMyActiveBid, withdrawMyPendingBid,
 * getBidsByShipment, acceptBid, including transactions + side-effects).
 */
'use strict';

const request = require('supertest');

const { buildTestApp } = require('../helpers/testApp');
const { dbMock } = require('../helpers/db');
const {
  tokenForDriver,
  tokenForShipper,
  authHeader,
} = require('../helpers/auth');
const {
  userFactory,
  shipperFactory,
  shipmentFactory,
  bidFactory,
} = require('../helpers/factories');

const app = () => buildTestApp({ routes: ['bids'] });

const expectExpiryProbe = () =>
  dbMock
    .expectUpdate(/UPDATE bids b\s+INNER JOIN shipments s/i)
    .returnsAffected(0);

const expectDriverUser = (id, overrides = {}) =>
  dbMock
    .expectSelect(/FROM users WHERE id = \?/i)
    .returns([userFactory({ id, ...overrides })]);

const expectShipperUser = (id, overrides = {}) =>
  dbMock
    .expectSelect(/FROM users WHERE id = \?/i)
    .returns([shipperFactory({ id, ...overrides })]);

const expectFindShipmentById = (row) =>
  dbMock
    .expectSelect(/FROM shipments s\s+LEFT JOIN users sh/i)
    .returns(row ? [row] : []);

describe('GET /api/bids/me/active', () => {
  test('403 when caller is not a driver', async () => {
    expectExpiryProbe();
    const res = await request(app())
      .get('/api/bids/me/active')
      .set(authHeader(tokenForShipper(200)));
    expect(res.status).toBe(403);
  });

  test('returns active: false when no participation', async () => {
    expectExpiryProbe();
    dbMock
      .expectSelect(/FROM bids b\s+INNER JOIN shipments s/i)
      .returns([]);
    const res = await request(app())
      .get('/api/bids/me/active')
      .set(authHeader(tokenForDriver(100)));
    expect(res.status).toBe(200);
    expect(res.body).toEqual({ active: false });
  });

  test('returns full payload when participation found', async () => {
    expectExpiryProbe();
    dbMock
      .expectSelect(/FROM bids b\s+INNER JOIN shipments s/i)
      .returns([
        {
          bid_id: 5000,
          shipment_id: 1000,
          bid_amount: 1450,
          estimated_days: 2,
          pickup_address: 'الرياض',
          dropoff_address: 'جدة',
        },
      ]);
    const res = await request(app())
      .get('/api/bids/me/active')
      .set(authHeader(tokenForDriver(100)));
    expect(res.status).toBe(200);
    expect(res.body.bid.bidId).toBe(5000);
  });

  test('500 when DB throws', async () => {
    expectExpiryProbe();
    dbMock
      .expectSelect(/FROM bids b\s+INNER JOIN shipments s/i)
      .rejectsWith(new Error('db'));
    const res = await request(app())
      .get('/api/bids/me/active')
      .set(authHeader(tokenForDriver(100)));
    expect(res.status).toBe(500);
  });
});

describe('POST /api/bids/me/withdraw', () => {
  test('403 when caller is not a driver', async () => {
    expectExpiryProbe();
    const res = await request(app())
      .post('/api/bids/me/withdraw')
      .set(authHeader(tokenForShipper(200)))
      .send({ shipmentId: 1000 });
    expect(res.status).toBe(403);
  });

  test('400 when shipmentId not a number', async () => {
    expectExpiryProbe();
    const res = await request(app())
      .post('/api/bids/me/withdraw')
      .set(authHeader(tokenForDriver(100)))
      .send({ shipmentId: 'NaN' });
    expect(res.status).toBe(400);
  });

  test('404 when no pending bid for explicit shipmentId', async () => {
    expectExpiryProbe();
    dbMock
      .expectSelect(/FROM bids WHERE shipment_id = \? AND driver_id = \? AND bid_status = \?/i)
      .returns([]);
    const res = await request(app())
      .post('/api/bids/me/withdraw')
      .set(authHeader(tokenForDriver(100)))
      .send({ shipmentId: 1000 });
    expect(res.status).toBe(404);
  });

  test('403 when driver is the current lowest bidder in a live auction', async () => {
    expectExpiryProbe();
    dbMock
      .expectSelect(/FROM bids WHERE shipment_id = \? AND driver_id = \? AND bid_status = \?/i)
      .returns([bidFactory({ id: 7, driver_id: 100 })]);
    expectFindShipmentById(
      shipmentFactory({
        id: 1000,
        status: 'bidding',
        auction_end_time: new Date(Date.now() + 24 * 3600 * 1000),
      }),
    );
    dbMock
      .expectSelect(/FROM bids WHERE shipment_id = \? AND bid_status = \? ORDER BY bid_amount ASC LIMIT 1/i)
      .returns([{ id: 7, driver_id: 100, bid_amount: 1200 }]);
    const res = await request(app())
      .post('/api/bids/me/withdraw')
      .set(authHeader(tokenForDriver(100)))
      .send({ shipmentId: 1000 });
    expect(res.status).toBe(403);
  });

  test('200 when withdraw is allowed (not currently winning)', async () => {
    expectExpiryProbe();
    dbMock
      .expectSelect(/FROM bids WHERE shipment_id = \? AND driver_id = \? AND bid_status = \?/i)
      .returns([bidFactory({ id: 7, driver_id: 100 })]);
    expectFindShipmentById(
      shipmentFactory({
        id: 1000,
        status: 'bidding',
        auction_end_time: new Date(Date.now() + 24 * 3600 * 1000),
      }),
    );
    dbMock
      .expectSelect(/FROM bids WHERE shipment_id = \? AND bid_status = \? ORDER BY bid_amount ASC LIMIT 1/i)
      .returns([{ id: 9, driver_id: 999, bid_amount: 1000 }]);
    dbMock
      .expectUpdate(/UPDATE bids SET bid_status = \? WHERE id = \?/i)
      .returnsAffected(1);
    const res = await request(app())
      .post('/api/bids/me/withdraw')
      .set(authHeader(tokenForDriver(100)))
      .send({ shipmentId: 1000 });
    expect(res.status).toBe(200);
    expect(res.body.bidId).toBe(7);
  });

  test('404 when no implicit active participation', async () => {
    expectExpiryProbe();
    dbMock
      .expectSelect(/FROM bids b\s+INNER JOIN shipments s/i)
      .returns([]);
    const res = await request(app())
      .post('/api/bids/me/withdraw')
      .set(authHeader(tokenForDriver(100)))
      .send({});
    expect(res.status).toBe(404);
  });

  test('500 when bids update fails', async () => {
    expectExpiryProbe();
    dbMock
      .expectSelect(/FROM bids WHERE shipment_id = \? AND driver_id = \? AND bid_status = \?/i)
      .returns([bidFactory({ id: 7, driver_id: 100 })]);
    expectFindShipmentById(
      shipmentFactory({
        id: 1000,
        status: 'bidding',
        auction_end_time: null,
      }),
    );
    dbMock
      .expectSelect(/FROM bids WHERE shipment_id = \? AND bid_status = \? ORDER BY bid_amount ASC LIMIT 1/i)
      .returns([{ id: 9, driver_id: 999, bid_amount: 1000 }]);
    dbMock
      .expectUpdate(/UPDATE bids SET bid_status = \? WHERE id = \?/i)
      .returnsAffected(0);
    const res = await request(app())
      .post('/api/bids/me/withdraw')
      .set(authHeader(tokenForDriver(100)))
      .send({ shipmentId: 1000 });
    expect(res.status).toBe(500);
  });
});

describe('POST /api/bids/ (createBid)', () => {
  const validBody = () => ({
    shipmentId: 1000,
    bidAmount: 1450,
    estimatedDays: 2,
  });

  test('401 without auth', async () => {
    const res = await request(app()).post('/api/bids/').send(validBody());
    expect(res.status).toBe(401);
  });

  test('400 when express-validator fails', async () => {
    expectDriverUser(100);
    const res = await request(app())
      .post('/api/bids/')
      .set(authHeader(tokenForDriver(100)))
      .send({ shipmentId: 'x', bidAmount: -1, estimatedDays: 0 });
    expect(res.status).toBe(400);
  });

  test('403 when caller is not a driver', async () => {
    expectShipperUser(200);
    expectExpiryProbe();
    const res = await request(app())
      .post('/api/bids/')
      .set(authHeader(tokenForShipper(200)))
      .send(validBody());
    expect(res.status).toBe(403);
  });

  test('403 when driver license is expired', async () => {
    expectDriverUser(100);
    expectExpiryProbe();
    expectDriverUser(100, { expiry_date: '2000-01-01' });
    const res = await request(app())
      .post('/api/bids/')
      .set(authHeader(tokenForDriver(100)))
      .send(validBody());
    expect(res.status).toBe(403);
    expect(res.body.message).toMatch(/الرخصة/);
  });

  test('404 when shipment missing', async () => {
    expectDriverUser(100);
    expectExpiryProbe();
    expectDriverUser(100);
    expectFindShipmentById(null);
    const res = await request(app())
      .post('/api/bids/')
      .set(authHeader(tokenForDriver(100)))
      .send(validBody());
    expect(res.status).toBe(404);
  });

  test('400 when shipment is not in bidding/pending status', async () => {
    expectDriverUser(100);
    expectExpiryProbe();
    expectDriverUser(100);
    expectFindShipmentById(shipmentFactory({ id: 1000, status: 'delivered' }));
    const res = await request(app())
      .post('/api/bids/')
      .set(authHeader(tokenForDriver(100)))
      .send(validBody());
    expect(res.status).toBe(400);
  });

  test('400 when auction is past', async () => {
    expectDriverUser(100);
    expectExpiryProbe();
    expectDriverUser(100);
    expectFindShipmentById(
      shipmentFactory({
        id: 1000,
        status: 'bidding',
        auction_end_time: new Date(Date.now() - 60 * 1000),
      }),
    );
    const res = await request(app())
      .post('/api/bids/')
      .set(authHeader(tokenForDriver(100)))
      .send(validBody());
    expect(res.status).toBe(400);
    expect(res.body.message).toMatch(/المزاد/);
  });

  test('400 when driver already has a pending bid', async () => {
    expectDriverUser(100);
    expectExpiryProbe();
    expectDriverUser(100);
    expectFindShipmentById(
      shipmentFactory({ id: 1000, status: 'bidding', auction_end_time: null }),
    );
    dbMock
      .expectSelect(/FROM bids WHERE shipment_id = \? AND driver_id = \? AND bid_status = \?/i)
      .returns([bidFactory({ id: 1 })]);
    const res = await request(app())
      .post('/api/bids/')
      .set(authHeader(tokenForDriver(100)))
      .send(validBody());
    expect(res.status).toBe(400);
  });

  test('409 when driver has active participation on another shipment', async () => {
    expectDriverUser(100);
    expectExpiryProbe();
    expectDriverUser(100);
    expectFindShipmentById(
      shipmentFactory({ id: 1000, status: 'bidding', auction_end_time: null }),
    );
    dbMock
      .expectSelect(/FROM bids WHERE shipment_id = \? AND driver_id = \? AND bid_status = \?/i)
      .returns([]);
    dbMock
      .expectSelect(/FROM bids b\s+INNER JOIN shipments s/i)
      .returns([{ bid_id: 99, shipment_id: 2222 }]);
    const res = await request(app())
      .post('/api/bids/')
      .set(authHeader(tokenForDriver(100)))
      .send(validBody());
    expect(res.status).toBe(409);
    expect(res.body.code).toBe('SINGLE_BID_ROOM');
  });

  test('201 creates bid and best-effort notifies + pushes', async () => {
    expectDriverUser(100);
    expectExpiryProbe();
    expectDriverUser(100);
    expectFindShipmentById(
      shipmentFactory({ id: 1000, status: 'bidding', auction_end_time: null }),
    );
    dbMock
      .expectSelect(/FROM bids WHERE shipment_id = \? AND driver_id = \? AND bid_status = \?/i)
      .returns([]);
    dbMock
      .expectSelect(/FROM bids b\s+INNER JOIN shipments s/i)
      .returns([]);
    dbMock.expectInsert(/INSERT INTO bids/i).returnsInsert(7777);
    const res = await request(app())
      .post('/api/bids/')
      .set(authHeader(tokenForDriver(100)))
      .send(validBody());
    expect(res.status).toBe(201);
    expect(res.body.id).toBe(7777);
  });

  test('201 still succeeds when notification raises (best-effort)', async () => {
    const Notification = require('../../models/Notification');
    Notification.create.mockImplementationOnce(async () => {
      throw new Error('notif failed');
    });

    expectDriverUser(100);
    expectExpiryProbe();
    expectDriverUser(100);
    expectFindShipmentById(
      shipmentFactory({ id: 1000, status: 'bidding', auction_end_time: null }),
    );
    dbMock
      .expectSelect(/FROM bids WHERE shipment_id = \? AND driver_id = \? AND bid_status = \?/i)
      .returns([]);
    dbMock
      .expectSelect(/FROM bids b\s+INNER JOIN shipments s/i)
      .returns([]);
    dbMock.expectInsert(/INSERT INTO bids/i).returnsInsert(8001);
    const res = await request(app())
      .post('/api/bids/')
      .set(authHeader(tokenForDriver(100)))
      .send(validBody());
    expect(res.status).toBe(201);
  });
});

describe('GET /api/bids/shipment/:shipmentId', () => {
  test('200 returns bids with parsed numbers', async () => {
    expectExpiryProbe();
    dbMock
      .expectSelect(/FROM bids b\s+LEFT JOIN users u/i)
      .returns([
        {
          id: 1,
          shipment_id: 1000,
          driver_id: 100,
          bid_amount: '1450.55',
          estimated_days: '3',
          bid_status: 'pending',
          driver_name: 'سائق',
          license_no: null,
          driver_rating: 4.5,
          rating_count: 12,
        },
      ]);
    const res = await request(app()).get('/api/bids/shipment/1000');
    expect(res.status).toBe(200);
    expect(res.body[0].bid_amount).toBeCloseTo(1450.55);
    expect(res.body[0].estimated_days).toBe(3);
  });

  test('500 on DB failure', async () => {
    expectExpiryProbe();
    dbMock
      .expectSelect(/FROM bids b\s+LEFT JOIN users u/i)
      .rejectsWith(new Error('boom'));
    const res = await request(app()).get('/api/bids/shipment/1000');
    expect(res.status).toBe(500);
  });
});

describe('POST /api/bids/:bidId/accept', () => {
  test('400 when bidId is not numeric', async () => {
    expectShipperUser(200);
    const res = await request(app())
      .post('/api/bids/abc/accept')
      .set(authHeader(tokenForShipper(200)));
    expect(res.status).toBe(400);
  });

  test('404 when bid not found', async () => {
    expectShipperUser(200);
    dbMock.expectSelect(/FROM bids WHERE id = \?/i).returns([]);
    const res = await request(app())
      .post('/api/bids/777/accept')
      .set(authHeader(tokenForShipper(200)));
    expect(res.status).toBe(404);
  });

  test('400 when bid is not pending', async () => {
    expectShipperUser(200);
    dbMock
      .expectSelect(/FROM bids WHERE id = \?/i)
      .returns([bidFactory({ id: 7, bid_status: 'rejected' })]);
    const res = await request(app())
      .post('/api/bids/7/accept')
      .set(authHeader(tokenForShipper(200)));
    expect(res.status).toBe(400);
  });

  test('403 when caller is not a shipper', async () => {
    expectDriverUser(100);
    dbMock
      .expectSelect(/FROM bids WHERE id = \?/i)
      .returns([bidFactory({ id: 7 })]);
    const res = await request(app())
      .post('/api/bids/7/accept')
      .set(authHeader(tokenForDriver(100)));
    expect(res.status).toBe(403);
  });

  test('404 when shipment not found', async () => {
    expectShipperUser(200);
    dbMock
      .expectSelect(/FROM bids WHERE id = \?/i)
      .returns([bidFactory({ id: 7, shipment_id: 1000, driver_id: 100 })]);
    expectFindShipmentById(null);
    const res = await request(app())
      .post('/api/bids/7/accept')
      .set(authHeader(tokenForShipper(200)));
    expect(res.status).toBe(404);
  });

  test('400 when shipment is not in bidding status', async () => {
    expectShipperUser(200);
    dbMock
      .expectSelect(/FROM bids WHERE id = \?/i)
      .returns([bidFactory({ id: 7, shipment_id: 1000, driver_id: 100 })]);
    expectFindShipmentById(shipmentFactory({ id: 1000, status: 'assigned' }));
    const res = await request(app())
      .post('/api/bids/7/accept')
      .set(authHeader(tokenForShipper(200)));
    expect(res.status).toBe(400);
  });

  test('403 when caller is not the owning shipper', async () => {
    expectShipperUser(999);
    dbMock
      .expectSelect(/FROM bids WHERE id = \?/i)
      .returns([bidFactory({ id: 7, shipment_id: 1000, driver_id: 100 })]);
    expectFindShipmentById(
      shipmentFactory({ id: 1000, shipper_id: 200, status: 'bidding' }),
    );
    const res = await request(app())
      .post('/api/bids/7/accept')
      .set(authHeader(tokenForShipper(999)));
    expect(res.status).toBe(403);
  });

  test('200 accepts bid, runs transaction + notifies others', async () => {
    expectShipperUser(200);
    dbMock
      .expectSelect(/FROM bids WHERE id = \?/i)
      .returns([
        bidFactory({ id: 7, shipment_id: 1000, driver_id: 100, bid_amount: 1450 }),
      ]);
    expectFindShipmentById(
      shipmentFactory({ id: 1000, shipper_id: 200, status: 'bidding' }),
    );
    // Transaction body
    dbMock.expectUpdate(/UPDATE bids SET bid_status = \? WHERE id = \?/i).returnsAffected(1);
    dbMock
      .expectUpdate(/UPDATE bids SET bid_status = \? WHERE shipment_id = \? AND id != \?/i)
      .returnsAffected(2);
    dbMock
      .expectUpdate(/UPDATE shipments SET status = \?, driver_id = \? WHERE id = \?/i)
      .returnsAffected(1);
    // Rejection drivers query (notification model is jest-mocked in setup.js
    // so INSERTs into notifications are *not* enqueued here).
    dbMock
      .expectSelect(/SELECT DISTINCT driver_id FROM bids WHERE shipment_id = \? AND id != \? AND bid_status = \?/i)
      .returns([{ driver_id: 101 }, { driver_id: 102 }]);
    // Contract generation queries shipper + driver users.
    dbMock
      .expectSelect(/FROM users WHERE id = \?/i)
      .returns([shipperFactory({ id: 200, full_name: 'مؤسسة' })]);
    dbMock
      .expectSelect(/FROM users WHERE id = \?/i)
      .returns([userFactory({ id: 100, full_name: 'سائق' })]);

    const res = await request(app())
      .post('/api/bids/7/accept')
      .set(authHeader(tokenForShipper(200)));
    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.bidId).toBe('7');
    expect(res.body.contract_pdf_key).toBe('contracts/test.pdf');
  });
});
