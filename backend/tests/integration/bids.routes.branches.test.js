/**
 * Branch coverage for bidController — best-effort catch blocks (notifications
 * + push), decryption fallback, withdrawMyPendingBid active-mode lookup, and
 * accept-bid contract-generation failure paths.
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

describe('POST /api/bids — createBid push catch branch', () => {
  test('201 still succeeds when sendPushToUser throws', async () => {
    const fcm = require('../../utils/fcmPush');
    jest.spyOn(fcm, 'sendPushToUser').mockImplementationOnce(async () => {
      throw new Error('FCM down');
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
    dbMock.expectInsert(/INSERT INTO bids/i).returnsInsert(8100);

    const res = await request(app())
      .post('/api/bids/')
      .set(authHeader(tokenForDriver(100)))
      .send({ shipmentId: 1000, bidAmount: 1450, estimatedDays: 2 });
    expect(res.status).toBe(201);
    expect(res.body.id).toBe(8100);
  });
});

describe('POST /api/bids/me/withdraw — active participation mode', () => {
  test('200 withdraws using active participation when shipmentId is omitted', async () => {
    expectExpiryProbe();
    // Bid.findActiveParticipationForDriver
    dbMock
      .expectSelect(/FROM bids b\s+INNER JOIN shipments s/i)
      .returns([{ bid_id: 70, shipment_id: 1000 }]);
    // Bid.findById (for the active bid)
    dbMock
      .expectSelect(/FROM bids WHERE id = \?/i)
      .returns([bidFactory({ id: 70, driver_id: 100 })]);
    expectFindShipmentById(
      shipmentFactory({ id: 1000, status: 'bidding', auction_end_time: null }),
    );
    dbMock
      .expectSelect(/FROM bids WHERE shipment_id = \? AND bid_status = \? ORDER BY bid_amount ASC LIMIT 1/i)
      .returns([{ id: 71, driver_id: 999, bid_amount: 1100 }]);
    dbMock
      .expectUpdate(/UPDATE bids SET bid_status = \? WHERE id = \?/i)
      .returnsAffected(1);
    const res = await request(app())
      .post('/api/bids/me/withdraw')
      .set(authHeader(tokenForDriver(100)))
      .send({});
    expect(res.status).toBe(200);
    expect(res.body.bidId).toBe(70);
  });

  test('500 when first SQL probe raises', async () => {
    // expireStaleAuctionBidsSafe swallows its own error; the outer 500 must
    // come from a query that runs INSIDE the try block. Make the explicit
    // probe (with shipmentId) throw.
    expectExpiryProbe();
    dbMock
      .expectSelect(/FROM bids WHERE shipment_id = \? AND driver_id = \? AND bid_status = \?/i)
      .rejectsWith(new Error('db down'));
    const res = await request(app())
      .post('/api/bids/me/withdraw')
      .set(authHeader(tokenForDriver(100)))
      .send({ shipmentId: 1000 });
    expect(res.status).toBe(500);
  });
});

describe('POST /api/bids/:bidId/accept — soft-failure branches', () => {
  const setupBaseExpectations = ({
    shipperId = 200,
    bidStatus = 'pending',
    shipmentId = 1000,
    driverId = 100,
    shipmentStatus = 'bidding',
  } = {}) => {
    expectShipperUser(shipperId);
    dbMock
      .expectSelect(/FROM bids WHERE id = \?/i)
      .returns([
        bidFactory({ id: 7, shipment_id: shipmentId, driver_id: driverId, bid_status: bidStatus, bid_amount: 1450 }),
      ]);
    expectFindShipmentById(
      shipmentFactory({ id: shipmentId, shipper_id: shipperId, status: shipmentStatus }),
    );
    dbMock.expectUpdate(/UPDATE bids SET bid_status = \? WHERE id = \?/i).returnsAffected(1);
    dbMock
      .expectUpdate(/UPDATE bids SET bid_status = \? WHERE shipment_id = \? AND id != \?/i)
      .returnsAffected(2);
    dbMock
      .expectUpdate(/UPDATE shipments SET status = \?, driver_id = \? WHERE id = \?/i)
      .returnsAffected(1);
    dbMock
      .expectSelect(/SELECT DISTINCT driver_id FROM bids WHERE shipment_id = \? AND id != \? AND bid_status = \?/i)
      .returns([{ driver_id: 101 }, { driver_id: 102 }]);
    dbMock
      .expectSelect(/FROM users WHERE id = \?/i)
      .returns([shipperFactory({ id: shipperId, full_name: 'مؤسسة' })]);
    dbMock
      .expectSelect(/FROM users WHERE id = \?/i)
      .returns([userFactory({ id: driverId, full_name: 'سائق' })]);
  };

  test('200 even when contract generation throws', async () => {
    const contractSvc = require('../../services/contractPdfService');
    contractSvc.generateAndStoreShipmentContract.mockImplementationOnce(async () => {
      throw new Error('pdf error');
    });
    setupBaseExpectations();
    const res = await request(app())
      .post('/api/bids/7/accept')
      .set(authHeader(tokenForShipper(200)));
    expect(res.status).toBe(200);
    expect(res.body.contract_pdf_key).toBeNull();
  });

  test('200 when sendPushToUser throws (post-accept)', async () => {
    const fcm = require('../../utils/fcmPush');
    jest.spyOn(fcm, 'sendPushToUser').mockImplementation(async () => {
      throw new Error('FCM down');
    });
    setupBaseExpectations();
    const res = await request(app())
      .post('/api/bids/7/accept')
      .set(authHeader(tokenForShipper(200)));
    expect(res.status).toBe(200);
    fcm.sendPushToUser.mockRestore();
  });

  test('200 when Notification.create throws inside the rejection loop', async () => {
    const Notification = require('../../models/Notification');
    let calls = 0;
    Notification.create.mockImplementation(async (payload) => {
      calls += 1;
      if (calls >= 2) throw new Error('notif boom'); // Driver-accept notif passes, rejections throw.
      return { id: 1, ...payload };
    });
    setupBaseExpectations();
    const res = await request(app())
      .post('/api/bids/7/accept')
      .set(authHeader(tokenForShipper(200)));
    expect(res.status).toBe(200);
  });
});

describe('GET /api/bids/shipment/:shipmentId — decryption fallback', () => {
  test('200 falls back to raw license_no when decryption fails', async () => {
    expectExpiryProbe();
    dbMock
      .expectSelect(/FROM bids b\s+LEFT JOIN users u/i)
      .returns([
        {
          id: 1,
          shipment_id: 1000,
          driver_id: 100,
          bid_amount: '1450',
          estimated_days: '3',
          bid_status: 'pending',
          driver_name: 'سائق',
          license_no: 'not-encrypted-hex-or-base64',
          driver_rating: null,
          rating_count: null,
        },
      ]);
    const res = await request(app()).get('/api/bids/shipment/1000');
    expect(res.status).toBe(200);
    expect(res.body[0].license_no).toBe('not-encrypted-hex-or-base64');
  });
});
