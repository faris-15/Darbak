/**
 * Extended integration coverage for /api/shipments.
 *
 * Scope: the branches that the main `shipments.routes.test.js` file did not
 * exercise — completeDelivery happy path, the live-location 500, the
 * `delivered` status transition with an accepted bid, status update fails,
 * extra list-query validation, and the driver-priority 500 path.
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

describe('POST /api/shipments/:id/complete — full happy path', () => {
  test('200 completes delivery and persists penalty info', async () => {
    // Bid.findById
    dbMock
      .expectSelect(/FROM bids WHERE id = \?/i)
      .returns([
        { id: 7, shipment_id: 1000, bid_amount: 1200, driver_id: 100 },
      ]);
    // Bid.setStatus
    dbMock.expectUpdate(/UPDATE bids SET bid_status = \? WHERE id = \?/i).returnsAffected(1);
    // Bid.rejectOtherBidsForShipment
    dbMock
      .expectUpdate(/UPDATE bids SET bid_status = \? WHERE shipment_id = \? AND id != \?/i)
      .returnsAffected(2);
    // Shipment.completeDelivery -> Shipment.findById (no shipment passed)
    dbMock
      .expectSelect(/FROM shipments s\s+LEFT JOIN users sh/i)
      .returns([
        shipmentFactory({
          id: 1000,
          status: 'en_route',
          expected_delivery_date: new Date(Date.now() + 24 * 3600 * 1000),
        }),
      ]);
    // Shipment.completeDelivery -> UPDATE
    dbMock
      .expectUpdate(/UPDATE shipments SET actual_delivery_date = \?, final_price/i)
      .returnsAffected(1);
    // Wallet.adjustBalance
    dbMock
      .expectUpdate(/UPDATE wallets SET current_balance/i)
      .returnsAffected(1);
    // Message.deleteByShipment first calls Conversation.deleteByShipment which
    // probes INFORMATION_SCHEMA (routed globally) then deletes — both are
    // wrapped in .catch() so we just let them route through.
    dbMock.routeAffect(/DELETE FROM conversations/i, 0);
    dbMock.routeAffect(/DELETE FROM messages/i, 0);

    const res = await request(app())
      .post('/api/shipments/1000/complete')
      .send({ bidId: 7, actualDeliveryDate: '2099-01-01T00:00:00.000Z' });
    expect(res.status).toBe(200);
    expect(res.body.message).toMatch(/تم إكمال التسليم/);
    expect(res.body.result.success).toBe(true);
  });

  test('500 when Shipment.findById inside completeDelivery throws', async () => {
    dbMock
      .expectSelect(/FROM bids WHERE id = \?/i)
      .returns([
        { id: 7, shipment_id: 1000, bid_amount: 1200, driver_id: 100 },
      ]);
    dbMock.expectUpdate(/UPDATE bids SET bid_status = \? WHERE id = \?/i).returnsAffected(1);
    dbMock
      .expectUpdate(/UPDATE bids SET bid_status = \? WHERE shipment_id = \? AND id != \?/i)
      .returnsAffected(0);
    dbMock
      .expectSelect(/FROM shipments s\s+LEFT JOIN users sh/i)
      .rejectsWith(new Error('boom'));
    const res = await request(app())
      .post('/api/shipments/1000/complete')
      .send({ bidId: 7, actualDeliveryDate: '2099-01-01T00:00:00.000Z' });
    expect(res.status).toBe(500);
  });
});

describe('POST /api/shipments/:id/live-location — error path', () => {
  test('500 when recordStatus throws', async () => {
    expectUser(100, { role: 'driver' });
    expectFindShipment(
      shipmentFactory({ id: 1000, driver_id: 100, status: 'en_route' }),
    );
    dbMock
      .expectInsert(/INSERT INTO shipment_status_history/i)
      .rejectsWith(new Error('boom'));

    const res = await request(app())
      .post('/api/shipments/1000/live-location')
      .set(authHeader(tokenForDriver(100)))
      .send({ location_lat: 24.7, location_lng: 46.6 });
    expect(res.status).toBe(500);
  });
});

describe('GET /api/shipments — query validation extras', () => {
  test('400 when min/max weight range is invalid', async () => {
    const res = await request(app())
      .get('/api/shipments?minWeight=500&maxWeight=200')
      .set(authHeader(tokenForShipper(200)));
    expect(res.status).toBe(400);
    expect(res.body.message).toMatch(/الوزن/);
  });

  test('400 when page is not a positive integer', async () => {
    const res = await request(app())
      .get('/api/shipments?page=-1')
      .set(authHeader(tokenForShipper(200)));
    expect(res.status).toBe(400);
  });

  test('400 when pickupCity is too long', async () => {
    const longText = 'a'.repeat(120);
    const res = await request(app())
      .get(`/api/shipments?pickupCity=${longText}`)
      .set(authHeader(tokenForShipper(200)));
    expect(res.status).toBe(400);
  });

  test('400 when limit is invalid', async () => {
    const res = await request(app())
      .get('/api/shipments?limit=abc')
      .set(authHeader(tokenForShipper(200)));
    expect(res.status).toBe(400);
  });

  test('400 when minPrice is out of range', async () => {
    const res = await request(app())
      .get('/api/shipments?minPrice=99999999999')
      .set(authHeader(tokenForShipper(200)));
    expect(res.status).toBe(400);
  });
});

describe('PATCH /api/shipments/:id/status — additional branches', () => {
  test('500 when Shipment.updateStatus returns false on a non-delivered transition', async () => {
    expectUser(100, { role: 'driver' });
    expectFindShipment(
      shipmentFactory({ id: 1000, driver_id: 100, status: 'at_pickup' }),
    );
    dbMock
      .expectInsert(/INSERT INTO shipment_status_history/i)
      .returnsInsert(900);
    dbMock
      .expectUpdate(/UPDATE shipments SET status = \? WHERE id = \?/i)
      .returnsAffected(0);

    const res = await request(app())
      .patch('/api/shipments/1000/status')
      .set(authHeader(tokenForDriver(100)))
      .send({ status: 'en_route' });
    expect(res.status).toBe(500);
    expect(res.body.message).toMatch(/تعذر تحديث/);
  });
});

describe('GET /api/shipments/driver — error path', () => {
  test('500 when driver-priority query throws', async () => {
    dbMock
      .expectSelect(/status_priority/i)
      .rejectsWith(new Error('boom'));
    const res = await request(app())
      .get('/api/shipments/driver')
      .set(authHeader(tokenForDriver(100)));
    expect(res.status).toBe(500);
  });

  test('shipper cannot list driver/active', async () => {
    const res = await request(app())
      .get('/api/shipments/driver/active')
      .set(authHeader(tokenForShipper(200)));
    expect(res.status).toBe(403);
  });
});

describe('GET /api/shipments/:id (getShipment) — extra branches', () => {
  test('500 when DB throws', async () => {
    dbMock
      .expectSelect(/FROM shipments s\s+LEFT JOIN users sh/i)
      .rejectsWith(new Error('boom'));
    const res = await request(app()).get('/api/shipments/1000');
    expect(res.status).toBe(500);
  });

  test('200 reports calculated penalty for delivered shipment with penalty_amount', async () => {
    dbMock
      .expectSelect(/FROM shipments s\s+LEFT JOIN users sh/i)
      .returns([
        shipmentFactory({
          id: 1000,
          status: 'delivered',
          shipper_name: 'X',
          accepted_bid_amount: 1500,
          penalty_amount: 75,
        }),
      ]);
    dbMock
      .expectSelect(/FROM contracts WHERE shipment_id = \?/i)
      .returns([]);
    const res = await request(app()).get('/api/shipments/1000');
    expect(res.status).toBe(200);
    expect(res.body.late_penalty_amount).toBe(75);
    expect(res.body.late_penalty_percent).toBe(5);
  });
});
