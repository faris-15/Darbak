/**
 * Branch-focused integration coverage for `/api/shipments/*` aimed at
 * lines/branches that are NOT exercised by either `shipments.routes.test.js`
 * or `shipments.routes.extra.test.js`:
 *
 *   - parseShipmentListQuery edge cases (empty filter values, availableOnly
 *     default statuses, too-long dropoff/cargo/truckGroup/truckCategory,
 *     invalid maxPrice/maxWeight, invalid truck-group)
 *   - createShipment validation paths (missing required fields, shipper not
 *     found, role not "shipper", open-shipments quota, invalid coordinates,
 *     invalid weight, invalid auction duration, truck-requirement failure)
 *   - getShipmentContractPdfUrl 500 path
 *   - attachShipperDisplayNames branches via getShipmentsForDriver
 *   - completeDelivery happy path with a real driver token (covers the
 *     400-not-owning-this-bid branch and the message-deletion .catch())
 *   - PATCH /api/shipments/:id/status delivered transition with no accepted
 *     bid (`Shipment.updateStatus` fallback)
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
  shipmentFactory,
} = require('../helpers/factories');

const app = () => buildTestApp({ routes: ['shipments'] });

const expectUser = (id, overrides = {}) =>
  dbMock
    .expectSelect(/FROM users WHERE id = \?/i)
    .returns([userFactory({ id, ...overrides })]);

const expectFindShipment = (row) =>
  dbMock
    .expectSelect(/FROM shipments s\s+LEFT JOIN users sh/i)
    .returns(row ? [row] : []);

describe('GET /api/shipments — additional validation branches', () => {
  test('400 when dropoffCity exceeds 80 chars', async () => {
    const long = 'a'.repeat(120);
    const res = await request(app())
      .get(`/api/shipments?dropoffCity=${long}`)
      .set(authHeader(tokenForShipper(200)));
    expect(res.status).toBe(400);
    expect(res.body.message).toMatch(/الوصول/);
  });

  test('400 when cargoCategory exceeds 80 chars', async () => {
    const long = 'a'.repeat(120);
    const res = await request(app())
      .get(`/api/shipments?cargoCategory=${long}`)
      .set(authHeader(tokenForShipper(200)));
    expect(res.status).toBe(400);
    expect(res.body.message).toMatch(/الحمولة/);
  });

  test('400 when minWeight is not numeric', async () => {
    const res = await request(app())
      .get('/api/shipments?minWeight=abc')
      .set(authHeader(tokenForShipper(200)));
    expect(res.status).toBe(400);
    expect(res.body.message).toMatch(/أقل وزن/);
  });

  test('400 when maxWeight is not numeric', async () => {
    const res = await request(app())
      .get('/api/shipments?maxWeight=abc')
      .set(authHeader(tokenForShipper(200)));
    expect(res.status).toBe(400);
  });

  test('200 skips empty status segments in comma-separated list', async () => {
    dbMock.route(/^SELECT COUNT\(\*\) AS total FROM shipments s/i, () => [
      [{ total: 0 }],
      { fieldCount: 0 },
    ]);
    dbMock.route(/^SELECT s\.\*/i, () => [[], { fieldCount: 0 }]);
    const res = await request(app()).get(
      '/api/shipments?status=bidding,,pending&page=1&limit=5',
    );
    expect(res.status).toBe(200);
  });

  test('400 when maxPrice is invalid', async () => {
    const res = await request(app())
      .get('/api/shipments?maxPrice=-1')
      .set(authHeader(tokenForShipper(200)));
    expect(res.status).toBe(400);
  });

  test('400 when truckGroup is invalid value', async () => {
    const res = await request(app())
      .get('/api/shipments?truckGroup=nonexistent_group')
      .set(authHeader(tokenForShipper(200)));
    expect(res.status).toBe(400);
  });

  test('400 when truckGroup is too long (>80)', async () => {
    const long = 'g'.repeat(120);
    const res = await request(app())
      .get(`/api/shipments?truckGroup=${long}`)
      .set(authHeader(tokenForShipper(200)));
    expect(res.status).toBe(400);
  });

  test('400 when truckCategory is too long (>80)', async () => {
    const long = 't'.repeat(120);
    const res = await request(app())
      .get(`/api/shipments?truckCategory=${long}`)
      .set(authHeader(tokenForShipper(200)));
    expect(res.status).toBe(400);
  });

  test('400 when status segment is unknown', async () => {
    const res = await request(app())
      .get('/api/shipments?status=delivered,unknown_status')
      .set(authHeader(tokenForShipper(200)));
    expect(res.status).toBe(400);
  });

  test('200 when availableOnly without status uses pending/bidding default', async () => {
    // listShipments has no requireAuth — req.user is undefined here.
    // The list SELECT also has COUNT(*) as a subquery so we route on the
    // leading `SELECT COUNT(*) AS total FROM shipments` pattern specifically.
    dbMock.route(/^SELECT COUNT\(\*\) AS total FROM shipments s/i, () => [
      [{ total: 0 }],
      { fieldCount: 0 },
    ]);
    dbMock.route(/^SELECT s\.\*/i, () => [[], { fieldCount: 0 }]);
    const res = await request(app()).get(
      '/api/shipments?availableOnly=1&page=1&limit=10'
    );
    expect(res.status).toBe(200);
    expect(res.body.data).toEqual([]);
  });

  test('200 ignores empty pickupCity= and continues without filter', async () => {
    dbMock.route(/^SELECT COUNT\(\*\) AS total FROM shipments s/i, () => [
      [{ total: 0 }],
      { fieldCount: 0 },
    ]);
    dbMock.route(/^SELECT s\.\*/i, () => [[], { fieldCount: 0 }]);
    const res = await request(app()).get(
      '/api/shipments?pickupCity=&page=1&limit=10'
    );
    expect(res.status).toBe(200);
  });
});

describe('POST /api/shipments — createShipment validation matrix', () => {
  // The full pipeline is requireAuth → KYB middleware (User.findById) →
  // express-validators → controller. Route the users probe globally so each
  // test only enqueues the business-specific SQL.
  const routeShipperKyb = () =>
    dbMock.route(/FROM users WHERE id = \?/i, () => [
      [userFactory({ id: 200, role: 'shipper', verification_status: 'verified' })],
      { fieldCount: 0 },
    ]);

  const routeDriverKyb = () =>
    dbMock.route(/FROM users WHERE id = \?/i, () => [
      [userFactory({ id: 100, role: 'driver', verification_status: 'verified' })],
      { fieldCount: 0 },
    ]);

  const validBody = (overrides = {}) => ({
    weightKg: 1000,
    cargoDescription: 'مواد بناء',
    pickupAddress: 'الرياض',
    dropoffAddress: 'جدة',
    pickupLat: 24.7,
    pickupLng: 46.6,
    dropoffLat: 21.5,
    dropoffLng: 39.2,
    suggestedPrice: 500,
    expectedDeliveryDate: '2099-01-01T00:00:00.000Z',
    period: '24h',
    ...overrides,
  });

  test('400 when express-validator rejects empty payload', async () => {
    routeShipperKyb();
    const res = await request(app())
      .post('/api/shipments')
      .set(authHeader(tokenForShipper(200)))
      .send({});
    expect(res.status).toBe(400);
    expect(res.body.errors).toBeDefined();
  });

  test('400 when coordinates are not finite numbers', async () => {
    routeShipperKyb();
    const res = await request(app())
      .post('/api/shipments')
      .set(authHeader(tokenForShipper(200)))
      .send(validBody({ pickupLat: 'x', pickupLng: 'x', dropoffLat: 'y', dropoffLng: 'y' }));
    expect(res.status).toBe(400);
    expect(res.body.message).toMatch(/إحداثيات/);
  });

  test('403 when caller is a driver (not shipper role)', async () => {
    routeDriverKyb();
    const res = await request(app())
      .post('/api/shipments')
      .set(authHeader(tokenForDriver(100)))
      .send(validBody());
    expect(res.status).toBe(403);
  });

  const expectCount = (cnt) =>
    dbMock
      .expectSelect(/SELECT COUNT\(\*\) AS cnt FROM shipments WHERE shipper_id/i)
      .returns([{ cnt }]);

  test('400 when shipper already has the maximum open shipments', async () => {
    routeShipperKyb();
    expectCount(5);
    const res = await request(app())
      .post('/api/shipments')
      .set(authHeader(tokenForShipper(200)))
      .send(validBody());
    expect(res.status).toBe(400);
    expect(res.body.code).toBe('LIMIT_EXCEEDED');
  });

  test('400 when suggested price cannot be parsed', async () => {
    routeShipperKyb();
    expectCount(0);
    const res = await request(app())
      .post('/api/shipments')
      .set(authHeader(tokenForShipper(200)))
      .send(validBody({ suggestedPrice: -10 }));
    expect(res.status).toBe(400);
  });

  test('400 when weight is zero or negative', async () => {
    routeShipperKyb();
    expectCount(0);
    const res = await request(app())
      .post('/api/shipments')
      .set(authHeader(tokenForShipper(200)))
      .send(validBody({ weightKg: -5 }));
    expect(res.status).toBe(400);
    expect(res.body.message).toMatch(/الوزن/);
  });

  test('400 when auction duration is not a positive integer', async () => {
    routeShipperKyb();
    expectCount(0);
    const res = await request(app())
      .post('/api/shipments')
      .set(authHeader(tokenForShipper(200)))
      .send(validBody({ auctionDurationHours: 0 }));
    expect(res.status).toBe(400);
  });

  test('404 when shipper account no longer exists in DB', async () => {
    // KYB middleware lookup succeeds, but the controller re-fetches and finds nothing.
    dbMock
      .expectSelect(/FROM users WHERE id = \?/i)
      .returns([userFactory({ id: 200, role: 'shipper', verification_status: 'verified' })]);
    dbMock.expectSelect(/FROM users WHERE id = \?/i).returns([]);
    const res = await request(app())
      .post('/api/shipments')
      .set(authHeader(tokenForShipper(200)))
      .send(validBody());
    expect(res.status).toBe(404);
    expect(res.body.code).toBe('NOT_FOUND');
  });

  test('400 when truck requirement payload is invalid', async () => {
    routeShipperKyb();
    expectCount(0);
    const res = await request(app())
      .post('/api/shipments')
      .set(authHeader(tokenForShipper(200)))
      .send(
        validBody({
          requiredTruckCategory: 'not_a_real_truck_category',
        }),
      );
    expect(res.status).toBe(400);
    expect(res.body.message).toMatch(/فئة الشاحنة/);
  });
});

describe('GET /api/shipments/:id/contract — 500 path', () => {
  test('500 when DB throws while fetching the shipment', async () => {
    dbMock
      .expectSelect(/FROM shipments s\s+LEFT JOIN users sh/i)
      .rejectsWith(new Error('db down'));
    const res = await request(app())
      .get('/api/shipments/1000/contract')
      .set(authHeader(tokenForShipper(200)));
    expect(res.status).toBe(500);
  });
});

describe('GET /api/shipments/driver — attachShipperDisplayNames branches', () => {
  test('200 backfills missing shipper_name from User.getFullNamesByIds', async () => {
    dbMock
      .expectSelect(/status_priority/i)
      .returns([
        { id: 1, shipper_id: 200, shipper_name: null, status: 'assigned' },
        { id: 2, shipper_id: 201, shipper_name: 'ALREADY SET', status: 'assigned' },
      ]);
    dbMock
      .expectSelect(/SELECT id, full_name FROM users WHERE id IN/i)
      .returns([{ id: 200, full_name: 'Original Shipper' }]);

    const res = await request(app())
      .get('/api/shipments/driver')
      .set(authHeader(tokenForDriver(100)));
    expect(res.status).toBe(200);
    expect(res.body[0].shipper_name).toBe('Original Shipper');
    expect(res.body[1].shipper_name).toBe('ALREADY SET');
  });

  test('200 returns array unchanged when all rows already have shipper_name', async () => {
    dbMock
      .expectSelect(/status_priority/i)
      .returns([
        { id: 1, shipper_id: 200, shipper_name: 'Has Name', status: 'assigned' },
      ]);
    const res = await request(app())
      .get('/api/shipments/driver')
      .set(authHeader(tokenForDriver(100)));
    expect(res.status).toBe(200);
    expect(res.body[0].shipper_name).toBe('Has Name');
  });

  test('200 empty list is returned untouched', async () => {
    dbMock
      .expectSelect(/status_priority/i)
      .returns([]);
    const res = await request(app())
      .get('/api/shipments/driver')
      .set(authHeader(tokenForDriver(100)));
    expect(res.status).toBe(200);
    expect(res.body).toEqual([]);
  });

  test('200 leaves shipper_name null when User lookup has no match', async () => {
    dbMock
      .expectSelect(/status_priority/i)
      .returns([{ id: 1, shipper_id: 999, shipper_name: null, status: 'assigned' }]);
    dbMock
      .expectSelect(/SELECT id, full_name FROM users WHERE id IN/i)
      .returns([]);
    const res = await request(app())
      .get('/api/shipments/driver')
      .set(authHeader(tokenForDriver(100)));
    expect(res.status).toBe(200);
    expect(res.body[0].shipper_name).toBeNull();
  });
});

describe('PATCH /api/shipments/:id/status — delivered branches', () => {
  beforeEach(() => {
    dbMock.route(/FROM INFORMATION_SCHEMA\.TABLES/i, () => [
      [{ count: 1 }],
      { fieldCount: 0 },
    ]);
    dbMock.routeAffect(/DELETE FROM conversations/i, 0);
    dbMock.routeAffect(/DELETE FROM messages/i, 0);
  });

  const deliveredShipment = () =>
    shipmentFactory({
      id: 1000,
      driver_id: 100,
      status: 'at_dropoff',
      expected_delivery_date: new Date(Date.now() - 48 * 3600 * 1000),
    });

  test('200 delivered with accepted bid runs completeDelivery + wallet credit', async () => {
    expectUser(100, { role: 'driver' });
    expectFindShipment(deliveredShipment());
    dbMock
      .expectInsert(/INSERT INTO shipment_status_history/i)
      .returnsInsert(3001);
    dbMock
      .route(/SELECT id, bid_amount FROM bids WHERE shipment_id = \? AND bid_status = "accepted"/i, () => [
        [{ id: 7, bid_amount: 1500 }],
        { fieldCount: 0 },
      ]);
    dbMock
      .expectUpdate(/UPDATE shipments SET actual_delivery_date = \?, final_price/i)
      .returnsAffected(1);
    dbMock
      .expectUpdate(/UPDATE wallets SET current_balance/i)
      .returnsAffected(1);
    expectFindShipment(
      shipmentFactory({ id: 1000, driver_id: 100, status: 'delivered' }),
    );

    const res = await request(app())
      .patch('/api/shipments/1000/status')
      .set(authHeader(tokenForDriver(100)))
      .send({ status: 'delivered', epodPhoto: 'proofs/epod-1000.jpg' });
    expect(res.status).toBe(200);
    expect(res.body.penalty).toMatchObject({
      final_price: expect.any(Number),
      penalty_amount: expect.any(Number),
    });
  });

  test('200 delivered without accepted bid falls back to updateStatus', async () => {
    expectUser(100, { role: 'driver' });
    expectFindShipment(deliveredShipment());
    dbMock
      .expectInsert(/INSERT INTO shipment_status_history/i)
      .returnsInsert(3002);
    dbMock
      .route(/SELECT id, bid_amount FROM bids WHERE shipment_id = \? AND bid_status = "accepted"/i, () => [
        [],
        { fieldCount: 0 },
      ]);
    dbMock
      .expectUpdate(/UPDATE shipments SET status = \? WHERE id = \?/i)
      .returnsAffected(1);
    expectFindShipment(
      shipmentFactory({ id: 1000, driver_id: 100, status: 'delivered' }),
    );

    const res = await request(app())
      .patch('/api/shipments/1000/status')
      .set(authHeader(tokenForDriver(100)))
      .send({ status: 'delivered', epodPhoto: 'proofs/epod-1000.jpg' });
    expect(res.status).toBe(200);
    expect(res.body.penalty).toBeNull();
  });

  test('500 when updateStatus returns false after delivered without bid', async () => {
    expectUser(100, { role: 'driver' });
    expectFindShipment(deliveredShipment());
    dbMock
      .expectInsert(/INSERT INTO shipment_status_history/i)
      .returnsInsert(3003);
    dbMock
      .route(/SELECT id, bid_amount FROM bids WHERE shipment_id = \? AND bid_status = "accepted"/i, () => [
        [],
        { fieldCount: 0 },
      ]);
    dbMock
      .expectUpdate(/UPDATE shipments SET status = \? WHERE id = \?/i)
      .returnsAffected(0);

    const res = await request(app())
      .patch('/api/shipments/1000/status')
      .set(authHeader(tokenForDriver(100)))
      .send({ status: 'delivered', epodPhoto: 'proofs/epod-1000.jpg' });
    expect(res.status).toBe(500);
  });
});

describe('POST /api/shipments/:id/complete — error branches', () => {
  beforeEach(() => {
    dbMock.route(/FROM INFORMATION_SCHEMA\.TABLES/i, () => [
      [{ count: 1 }],
      { fieldCount: 0 },
    ]);
  });

  test('200 still succeeds when chat cleanup throws (best-effort)', async () => {
    dbMock
      .expectSelect(/FROM bids WHERE id = \?/i)
      .returns([{ id: 7, shipment_id: 1000, bid_amount: 1200, driver_id: 100 }]);
    dbMock.expectUpdate(/UPDATE bids SET bid_status = \? WHERE id = \?/i).returnsAffected(1);
    dbMock
      .expectUpdate(/UPDATE bids SET bid_status = \? WHERE shipment_id = \? AND id != \?/i)
      .returnsAffected(1);
    dbMock
      .expectSelect(/FROM shipments s\s+LEFT JOIN users sh/i)
      .returns([
        shipmentFactory({
          id: 1000,
          status: 'en_route',
          expected_delivery_date: new Date(Date.now() + 24 * 3600 * 1000),
        }),
      ]);
    dbMock
      .expectUpdate(/UPDATE shipments SET actual_delivery_date = \?, final_price/i)
      .returnsAffected(1);
    dbMock
      .expectUpdate(/UPDATE wallets SET current_balance/i)
      .returnsAffected(1);
    dbMock.route(/DELETE FROM messages/i, () => {
      throw new Error('chat delete failed');
    });

    const res = await request(app())
      .post('/api/shipments/1000/complete')
      .send({ bidId: 7, actualDeliveryDate: '2099-01-01T00:00:00.000Z' });
    expect(res.status).toBe(200);
    expect(res.body.result.success).toBe(true);
  });

  test('404 when bid not found', async () => {
    dbMock.expectSelect(/FROM bids WHERE id = \?/i).returns([]);
    const res = await request(app())
      .post('/api/shipments/1000/complete')
      .send({ bidId: 9999, actualDeliveryDate: '2099-01-01' });
    expect(res.status).toBe(404);
  });

  test('400 when bid belongs to another shipment', async () => {
    dbMock
      .expectSelect(/FROM bids WHERE id = \?/i)
      .returns([{ id: 7, shipment_id: 4242, bid_amount: 1000, driver_id: 100 }]);
    const res = await request(app())
      .post('/api/shipments/1000/complete')
      .send({ bidId: 7, actualDeliveryDate: '2099-01-01' });
    expect(res.status).toBe(400);
  });
});

describe('GET /api/shipments — search pipeline executes', () => {
  // The GET /api/shipments route has no auth middleware, so the matchMyTruck
  // branch in the controller depends on `req.user?.role === 'driver'`. Exercise
  // the rest of the parse + search pipeline with a non-auth request that
  // passes the validator gates.
  test('200 with truckCategory filter resolves through Shipment.search', async () => {
    dbMock.route(/^SELECT COUNT\(\*\) AS total FROM shipments s/i, () => [
      [{ total: 0 }],
      { fieldCount: 0 },
    ]);
    dbMock.route(/^SELECT s\.\*/i, () => [[], { fieldCount: 0 }]);
    const res = await request(app())
      .get('/api/shipments?truckCategory=medium_double_5_10&page=1&limit=5');
    expect(res.status).toBe(200);
  });
});
