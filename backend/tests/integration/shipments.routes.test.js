/**
 * Integration tests for /api/shipments. Exercises the full lifecycle:
 * create, list (legacy + paginated + driver matchMyTruck), getShipment,
 * contract-pdf, live-location, status update, completeDelivery, and the
 * driver-active/driver-priority feeds.
 */
'use strict';

const request = require('supertest');

const { buildTestApp } = require('../helpers/testApp');
const { dbMock } = require('../helpers/db');
const {
  tokenForDriver,
  tokenForShipper,
  tokenForAdmin,
  authHeader,
} = require('../helpers/auth');
const {
  userFactory,
  shipperFactory,
  shipmentFactory,
  truckFactory,
} = require('../helpers/factories');

const app = () => buildTestApp({ routes: ['shipments'] });

const stubShipmentTruckSchemaProbe = () =>
  dbMock.route(/FROM INFORMATION_SCHEMA.COLUMNS/i, () => [
    [{ count: 1 }],
    { fieldCount: 0 },
  ]);

const expectUser = (id, overrides = {}) =>
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

describe('POST /api/shipments (createShipment)', () => {
  beforeEach(() => stubShipmentTruckSchemaProbe());

  const validBody = () => ({
    weightKg: 5000,
    cargoDescription: 'مواد بناء',
    pickupAddress: 'الرياض',
    dropoffAddress: 'جدة',
    pickupLat: 24.7,
    pickupLng: 46.6,
    dropoffLat: 21.4,
    dropoffLng: 39.8,
    suggestedPrice: 1500,
    expectedDeliveryDate: '2099-12-31T12:00:00.000Z',
    period: 'صباحي',
  });

  test('401 without auth', async () => {
    const res = await request(app()).post('/api/shipments').send(validBody());
    expect(res.status).toBe(401);
  });

  test('400 when express-validator fails (weight non-numeric)', async () => {
    expectShipperUser(200);
    const res = await request(app())
      .post('/api/shipments')
      .set(authHeader(tokenForShipper(200)))
      .send({ ...validBody(), weightKg: 'abc' });
    expect(res.status).toBe(400);
    expect(res.body.errors).toBeDefined();
  });

  test('400 when neither suggestedPrice nor basePrice provided', async () => {
    expectShipperUser(200);
    const body = validBody();
    delete body.suggestedPrice;
    const res = await request(app())
      .post('/api/shipments')
      .set(authHeader(tokenForShipper(200)))
      .send(body);
    expect(res.status).toBe(400);
  });

  test('400 when coordinates are invalid', async () => {
    expectShipperUser(200);
    expectShipperUser(200);
    const res = await request(app())
      .post('/api/shipments')
      .set(authHeader(tokenForShipper(200)))
      .send({ ...validBody(), pickupLat: 'NaN' });
    expect(res.status).toBe(400);
    expect(res.body.message).toMatch(/إحداثيات/);
  });

  test('403 when role is not shipper', async () => {
    expectUser(100, { role: 'driver' });
    expectUser(100, { role: 'driver' });
    const res = await request(app())
      .post('/api/shipments')
      .set(authHeader(tokenForDriver(100)))
      .send(validBody());
    expect(res.status).toBe(403);
  });

  test('400 when shipper exceeds open shipment limit', async () => {
    expectShipperUser(200);
    expectShipperUser(200);
    dbMock
      .expectSelect(/SELECT COUNT\(\*\) AS cnt FROM shipments/i)
      .returns([{ cnt: 5 }]);
    const res = await request(app())
      .post('/api/shipments')
      .set(authHeader(tokenForShipper(200)))
      .send(validBody());
    expect(res.status).toBe(400);
    expect(res.body.code).toBe('LIMIT_EXCEEDED');
  });

  test('400 when suggested price is zero or invalid', async () => {
    expectShipperUser(200);
    expectShipperUser(200);
    dbMock
      .expectSelect(/SELECT COUNT\(\*\) AS cnt FROM shipments/i)
      .returns([{ cnt: 0 }]);
    const res = await request(app())
      .post('/api/shipments')
      .set(authHeader(tokenForShipper(200)))
      .send({ ...validBody(), suggestedPrice: 0 });
    expect(res.status).toBe(400);
    expect(res.body.message).toMatch(/السعر المقترح/);
  });

  test('400 when weight is non-positive', async () => {
    expectShipperUser(200);
    expectShipperUser(200);
    dbMock
      .expectSelect(/SELECT COUNT\(\*\) AS cnt FROM shipments/i)
      .returns([{ cnt: 0 }]);
    const res = await request(app())
      .post('/api/shipments')
      .set(authHeader(tokenForShipper(200)))
      .send({ ...validBody(), weightKg: -1 });
    expect(res.status).toBe(400);
    expect(res.body.message).toMatch(/الوزن/);
  });

  test('400 when auctionDurationHours is invalid', async () => {
    expectShipperUser(200);
    expectShipperUser(200);
    dbMock
      .expectSelect(/SELECT COUNT\(\*\) AS cnt FROM shipments/i)
      .returns([{ cnt: 0 }]);
    const res = await request(app())
      .post('/api/shipments')
      .set(authHeader(tokenForShipper(200)))
      .send({ ...validBody(), auctionDurationHours: -1 });
    expect(res.status).toBe(400);
    expect(res.body.message).toMatch(/مدة المزاد/);
  });

  test('201 creates shipment successfully', async () => {
    expectShipperUser(200);
    expectShipperUser(200);
    dbMock
      .expectSelect(/SELECT COUNT\(\*\) AS cnt FROM shipments/i)
      .returns([{ cnt: 2 }]);
    dbMock.expectInsert(/INSERT INTO shipments/i).returnsInsert(7777);

    const res = await request(app())
      .post('/api/shipments')
      .set(authHeader(tokenForShipper(200)))
      .send(validBody());
    expect(res.status).toBe(201);
    expect(res.body.id).toBe(7777);
    expect(res.body.status).toBe('bidding');
    expect(res.body.required_min_capacity_tons).toBeCloseTo(5);
  });

  test('500 when INSERT throws', async () => {
    expectShipperUser(200);
    expectShipperUser(200);
    dbMock
      .expectSelect(/SELECT COUNT\(\*\) AS cnt FROM shipments/i)
      .returns([{ cnt: 0 }]);
    dbMock
      .expectInsert(/INSERT INTO shipments/i)
      .rejectsWith(new Error('db down'));

    const res = await request(app())
      .post('/api/shipments')
      .set(authHeader(tokenForShipper(200)))
      .send(validBody());
    expect(res.status).toBe(500);
  });
});

describe('GET /api/shipments (listShipments)', () => {
  test('returns raw array for shipper without query params', async () => {
    dbMock
      .expectSelect(/SELECT s\.\*/i)
      .returns([shipmentFactory({ id: 1, shipper_id: 200 })]);
    const res = await request(app())
      .get('/api/shipments')
      .set(authHeader(tokenForShipper(200)));
    expect(res.status).toBe(200);
    expect(Array.isArray(res.body)).toBe(true);
  });

  test('returns paginated envelope when pagination provided', async () => {
    dbMock
      .expectSelect(/SELECT COUNT\(\*\) AS total FROM shipments/i)
      .returns([{ total: 3 }]);
    dbMock
      .expectSelect(/SELECT s\.\*/i)
      .returns([
        shipmentFactory({ id: 1 }),
        shipmentFactory({ id: 2 }),
        shipmentFactory({ id: 3 }),
      ]);
    const res = await request(app())
      .get('/api/shipments?page=1&limit=10')
      .set(authHeader(tokenForShipper(200)));
    expect(res.status).toBe(200);
    expect(res.body.pagination).toMatchObject({ total: 3, totalPages: 1 });
    expect(res.body.data).toHaveLength(3);
  });

  test('400 when status filter is unknown', async () => {
    const res = await request(app())
      .get('/api/shipments?status=garbage')
      .set(authHeader(tokenForShipper(200)));
    expect(res.status).toBe(400);
  });

  test('400 when min price > max price', async () => {
    const res = await request(app())
      .get('/api/shipments?minPrice=200&maxPrice=100')
      .set(authHeader(tokenForShipper(200)));
    expect(res.status).toBe(400);
    expect(res.body.message).toMatch(/السعر/);
  });

  test('returns paginated empty result when filters do not match', async () => {
    dbMock
      .expectSelect(/SELECT COUNT\(\*\) AS total FROM shipments/i)
      .returns([{ total: 0 }]);
    dbMock.expectSelect(/SELECT s\.\*/i).returns([]);
    const res = await request(app())
      .get('/api/shipments?page=1&limit=10&status=pending&minPrice=10&maxPrice=20&minWeight=100&maxWeight=200')
      .set(authHeader(tokenForShipper(200)));
    expect(res.status).toBe(200);
    expect(res.body.data).toHaveLength(0);
  });

  test('400 when truck group is invalid', async () => {
    const res = await request(app())
      .get('/api/shipments?truckGroup=bogus')
      .set(authHeader(tokenForShipper(200)));
    expect(res.status).toBe(400);
  });

  test('400 when filter text is too long', async () => {
    const longText = 'a'.repeat(200);
    const res = await request(app())
      .get(`/api/shipments?q=${longText}`)
      .set(authHeader(tokenForShipper(200)));
    expect(res.status).toBe(400);
  });

  test('500 when DB throws', async () => {
    dbMock
      .expectSelect(/SELECT s\.\*/i)
      .rejectsWith(new Error('boom'));
    const res = await request(app())
      .get('/api/shipments')
      .set(authHeader(tokenForShipper(200)));
    expect(res.status).toBe(500);
  });
});

describe('GET /api/shipments/:id (getShipment)', () => {
  test('404 when shipment missing', async () => {
    expectFindShipmentById(null);
    const res = await request(app()).get('/api/shipments/9999');
    expect(res.status).toBe(404);
  });

  test('200 returns shipment with contract key + penalty fields', async () => {
    expectFindShipmentById(
      shipmentFactory({
        id: 1000,
        shipper_id: 200,
        driver_id: 100,
        status: 'en_route',
        expected_delivery_date: new Date(Date.now() - 24 * 3600 * 1000),
        accepted_bid_amount: 1500,
        shipper_name: 'مؤسسة',
      }),
    );
    dbMock
      .expectSelect(/FROM contracts WHERE shipment_id = \?/i)
      .returns([{ pdf_key: 'contracts/1000.pdf' }]);
    const res = await request(app()).get('/api/shipments/1000');
    expect(res.status).toBe(200);
    expect(res.body.contract_pdf_key).toBe('contracts/1000.pdf');
    expect(res.body.late_penalty_percent).toBeGreaterThanOrEqual(0);
  });

  test('falls back to User.findById when shipper_name is empty', async () => {
    expectFindShipmentById(
      shipmentFactory({
        id: 1000,
        shipper_id: 200,
        status: 'pending',
        shipper_name: '',
      }),
    );
    dbMock
      .expectSelect(/FROM contracts WHERE shipment_id = \?/i)
      .returns([]);
    dbMock
      .expectSelect(/FROM users WHERE id = \?/i)
      .returns([userFactory({ id: 200, full_name: 'مؤسسة المرسل' })]);
    const res = await request(app()).get('/api/shipments/1000');
    expect(res.status).toBe(200);
    expect(res.body.shipper_name).toBe('مؤسسة المرسل');
  });

  test('survives missing contracts table', async () => {
    expectFindShipmentById(shipmentFactory({ id: 1000, shipper_name: 'X' }));
    dbMock
      .expectSelect(/FROM contracts WHERE shipment_id = \?/i)
      .rejectsWith(new Error("Table 'contracts' doesn't exist"));
    const res = await request(app()).get('/api/shipments/1000');
    expect(res.status).toBe(200);
    expect(res.body.contract_pdf_key).toBeNull();
  });

  test('reports zero penalty for delivered shipment without penalty', async () => {
    expectFindShipmentById(
      shipmentFactory({
        id: 1000,
        status: 'delivered',
        shipper_name: 'X',
        accepted_bid_amount: 1500,
        penalty_amount: 0,
      }),
    );
    dbMock
      .expectSelect(/FROM contracts WHERE shipment_id = \?/i)
      .returns([]);
    const res = await request(app()).get('/api/shipments/1000');
    expect(res.status).toBe(200);
    expect(res.body.late_penalty_percent).toBe(0);
    expect(res.body.late_penalty_amount).toBe(0);
  });
});

describe('GET /api/shipments/:id/contract', () => {
  test('401 without auth', async () => {
    const res = await request(app()).get('/api/shipments/1000/contract');
    expect(res.status).toBe(401);
  });

  test('404 when shipment missing', async () => {
    expectFindShipmentById(null);
    const res = await request(app())
      .get('/api/shipments/1000/contract')
      .set(authHeader(tokenForShipper(200)));
    expect(res.status).toBe(404);
  });

  test('403 when caller is not the shipper or driver', async () => {
    expectFindShipmentById(
      shipmentFactory({ id: 1000, shipper_id: 200, driver_id: 100 }),
    );
    const res = await request(app())
      .get('/api/shipments/1000/contract')
      .set(authHeader(tokenForShipper(999)));
    expect(res.status).toBe(403);
  });

  test('404 when no contract row', async () => {
    expectFindShipmentById(
      shipmentFactory({ id: 1000, shipper_id: 200, driver_id: 100 }),
    );
    dbMock
      .expectSelect(/FROM contracts WHERE shipment_id = \?/i)
      .returns([]);
    const res = await request(app())
      .get('/api/shipments/1000/contract')
      .set(authHeader(tokenForShipper(200)));
    expect(res.status).toBe(404);
  });

  test('200 returns presigned URL when contract found', async () => {
    expectFindShipmentById(
      shipmentFactory({ id: 1000, shipper_id: 200, driver_id: 100 }),
    );
    dbMock
      .expectSelect(/FROM contracts WHERE shipment_id = \?/i)
      .returns([{ pdf_key: 'contracts/1000.pdf' }]);
    const res = await request(app())
      .get('/api/shipments/1000/contract')
      .set(authHeader(tokenForShipper(200)));
    expect(res.status).toBe(200);
    expect(res.body.url).toMatch(/test-s3.local/);
    expect(res.body.pdf_key).toBe('contracts/1000.pdf');
  });
});

describe('POST /api/shipments/:id/live-location', () => {
  test('403 when caller is not a driver', async () => {
    expectShipperUser(200);
    const res = await request(app())
      .post('/api/shipments/1000/live-location')
      .set(authHeader(tokenForShipper(200)))
      .send({ location_lat: 24.7, location_lng: 46.6 });
    expect(res.status).toBe(403);
  });

  test('400 when coordinates are invalid', async () => {
    expectUser(100, { role: 'driver' });
    const res = await request(app())
      .post('/api/shipments/1000/live-location')
      .set(authHeader(tokenForDriver(100)))
      .send({ location_lat: 'a', location_lng: 'b' });
    expect(res.status).toBe(400);
  });

  test('404 when shipment missing', async () => {
    expectUser(100, { role: 'driver' });
    expectFindShipmentById(null);
    const res = await request(app())
      .post('/api/shipments/1000/live-location')
      .set(authHeader(tokenForDriver(100)))
      .send({ location_lat: 24.7, location_lng: 46.6 });
    expect(res.status).toBe(404);
  });

  test('403 when caller is not the assigned driver', async () => {
    expectUser(100, { role: 'driver' });
    expectFindShipmentById(
      shipmentFactory({ id: 1000, driver_id: 999, status: 'en_route' }),
    );
    const res = await request(app())
      .post('/api/shipments/1000/live-location')
      .set(authHeader(tokenForDriver(100)))
      .send({ location_lat: 24.7, location_lng: 46.6 });
    expect(res.status).toBe(403);
  });

  test('400 when shipment is not in an active status', async () => {
    expectUser(100, { role: 'driver' });
    expectFindShipmentById(
      shipmentFactory({ id: 1000, driver_id: 100, status: 'delivered' }),
    );
    const res = await request(app())
      .post('/api/shipments/1000/live-location')
      .set(authHeader(tokenForDriver(100)))
      .send({ location_lat: 24.7, location_lng: 46.6 });
    expect(res.status).toBe(400);
  });

  test('200 records driver live location', async () => {
    expectUser(100, { role: 'driver' });
    expectFindShipmentById(
      shipmentFactory({ id: 1000, driver_id: 100, status: 'en_route' }),
    );
    dbMock.expectInsert(/INSERT INTO shipment_status_history/i).returnsInsert(2200);

    const res = await request(app())
      .post('/api/shipments/1000/live-location')
      .set(authHeader(tokenForDriver(100)))
      .send({ location_lat: 24.7, location_lng: 46.6 });
    expect(res.status).toBe(200);
    expect(res.body.history?.id).toBe(2200);
  });
});

describe('POST /api/shipments/:id/complete', () => {
  test('400 when validator fails', async () => {
    const res = await request(app())
      .post('/api/shipments/1000/complete')
      .send({ bidId: 'x', actualDeliveryDate: 'not-a-date' });
    expect(res.status).toBe(400);
  });

  test('404 when bid missing', async () => {
    dbMock.expectSelect(/FROM bids WHERE id = \?/i).returns([]);
    const res = await request(app())
      .post('/api/shipments/1000/complete')
      .send({ bidId: 9999, actualDeliveryDate: '2026-01-01T00:00:00.000Z' });
    expect(res.status).toBe(404);
  });

  test('400 when bid does not belong to shipment', async () => {
    dbMock
      .expectSelect(/FROM bids WHERE id = \?/i)
      .returns([{ id: 7, shipment_id: 9999, bid_amount: 1000, driver_id: 100 }]);
    const res = await request(app())
      .post('/api/shipments/1000/complete')
      .send({ bidId: 7, actualDeliveryDate: '2026-01-01T00:00:00.000Z' });
    expect(res.status).toBe(400);
  });
});

describe('GET /api/shipments/driver and /driver/active', () => {
  test('/driver 403 when role is not driver', async () => {
    const res = await request(app())
      .get('/api/shipments/driver')
      .set(authHeader(tokenForShipper(200)));
    expect(res.status).toBe(403);
  });

  test('/driver/active 200 returns shipments and resolves missing shipper names', async () => {
    dbMock
      .expectSelect(/FROM shipments s\s+LEFT JOIN users sh.*driver_id = \?/i)
      .returns([
        shipmentFactory({ id: 1, shipper_id: 200, driver_id: 100, shipper_name: null, status: 'assigned' }),
      ]);
    dbMock
      .expectSelect(/FROM users WHERE id IN \(\?\)/i)
      .returns([{ id: 200, full_name: 'مؤسسة' }]);
    const res = await request(app())
      .get('/api/shipments/driver/active')
      .set(authHeader(tokenForDriver(100)));
    expect(res.status).toBe(200);
    expect(res.body[0].shipper_name).toBe('مؤسسة');
  });

  test('/driver 200 returns driver-priority list', async () => {
    dbMock
      .expectSelect(/status_priority/i)
      .returns([
        shipmentFactory({ id: 2, shipper_name: 'X', shipper_id: 200 }),
      ]);
    const res = await request(app())
      .get('/api/shipments/driver')
      .set(authHeader(tokenForDriver(100)));
    expect(res.status).toBe(200);
  });

  test('/driver/active 500 on db failure', async () => {
    dbMock
      .expectSelect(/FROM shipments s\s+LEFT JOIN users sh.*driver_id = \?/i)
      .rejectsWith(new Error('boom'));
    const res = await request(app())
      .get('/api/shipments/driver/active')
      .set(authHeader(tokenForDriver(100)));
    expect(res.status).toBe(500);
  });
});

describe('PATCH /api/shipments/:id/status', () => {
  test('403 when caller is shipper', async () => {
    expectShipperUser(200);
    const res = await request(app())
      .patch('/api/shipments/1000/status')
      .set(authHeader(tokenForShipper(200)))
      .send({ status: 'en_route' });
    expect(res.status).toBe(403);
  });

  test('400 when status not in lifecycle list', async () => {
    expectUser(100, { role: 'driver' });
    const res = await request(app())
      .patch('/api/shipments/1000/status')
      .set(authHeader(tokenForDriver(100)))
      .send({ status: 'bidding' });
    expect(res.status).toBe(400);
  });

  test('404 when shipment missing', async () => {
    expectUser(100, { role: 'driver' });
    expectFindShipmentById(null);
    const res = await request(app())
      .patch('/api/shipments/1000/status')
      .set(authHeader(tokenForDriver(100)))
      .send({ status: 'en_route' });
    expect(res.status).toBe(404);
  });

  test('403 when caller is not the assigned driver', async () => {
    expectUser(100, { role: 'driver' });
    expectFindShipmentById(
      shipmentFactory({ id: 1000, driver_id: 999, status: 'assigned' }),
    );
    const res = await request(app())
      .patch('/api/shipments/1000/status')
      .set(authHeader(tokenForDriver(100)))
      .send({ status: 'en_route' });
    expect(res.status).toBe(403);
  });

  test('400 when delivered without epod photo', async () => {
    expectUser(100, { role: 'driver' });
    expectFindShipmentById(
      shipmentFactory({ id: 1000, driver_id: 100, status: 'en_route' }),
    );
    const res = await request(app())
      .patch('/api/shipments/1000/status')
      .set(authHeader(tokenForDriver(100)))
      .send({ status: 'delivered' });
    expect(res.status).toBe(400);
  });

  test('200 advances to en_route', async () => {
    expectUser(100, { role: 'driver' });
    expectFindShipmentById(
      shipmentFactory({ id: 1000, driver_id: 100, status: 'at_pickup' }),
    );
    dbMock
      .expectInsert(/INSERT INTO shipment_status_history/i)
      .returnsInsert(3001);
    dbMock
      .expectUpdate(/UPDATE shipments SET status = \? WHERE id = \?/i)
      .returnsAffected(1);
    expectFindShipmentById(
      shipmentFactory({ id: 1000, driver_id: 100, status: 'en_route' }),
    );

    const res = await request(app())
      .patch('/api/shipments/1000/status')
      .set(authHeader(tokenForDriver(100)))
      .send({ status: 'en_route' });
    expect(res.status).toBe(200);
    expect(res.body.shipment.status).toBe('en_route');
  });
});
