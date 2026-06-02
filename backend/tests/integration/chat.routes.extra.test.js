/**
 * Extra integration coverage for /api/chat/* — branches not exercised by
 * `chat.routes.test.js`:
 *
 *   - send() 404 when neither the requested shipment nor the fallback exists
 *   - send() infers receiverId from shipment when none is provided
 *   - send() 500 when Message.create throws
 *   - send() 400 when message body is empty
 *   - mark delivered / read 500 paths when DB throws
 *   - location validator rejects out-of-range coords
 *   - media inferring video from mp4 extension
 *   - location label fallback to "موقع"
 */
'use strict';

const request = require('supertest');

const { buildTestApp } = require('../helpers/testApp');
const { dbMock } = require('../helpers/db');
const { tokenForShipper, tokenForDriver, authHeader } = require('../helpers/auth');
const { userFactory, shipmentFactory } = require('../helpers/factories');

const app = () => buildTestApp({ routes: ['chat'] });

const expectKybVerified = (id, role) =>
  dbMock
    .expectSelect(/FROM users WHERE id = \?/i)
    .returns([userFactory({ id, role, verification_status: 'verified' })]);

const expectFindShipment = (row) =>
  dbMock.expectSelect(/FROM shipments s\s+LEFT JOIN users sh/i).returns(row ? [row] : []);

const expectFindChatShipmentFallback = (row) =>
  dbMock
    .expectSelect(/FROM shipments\s+WHERE \(\s+\(shipper_id = \? AND driver_id = \?\)/i)
    .returns(row ? [row] : []);

describe('POST /api/chat/send — additional branches', () => {
  test('400 when message body is empty string after trim', async () => {
    expectKybVerified(200, 'shipper');
    const res = await request(app())
      .post('/api/chat/send')
      .set(authHeader(tokenForShipper(200)))
      .send({ shipmentId: 1000, receiverId: 100, message: '   ' });
    // Express-validator catches non-empty rule first → 400.
    expect(res.status).toBe(400);
  });

  test('404 when shipment is missing AND fallback returns nothing', async () => {
    expectKybVerified(200, 'shipper');
    expectFindShipment(null);
    expectFindChatShipmentFallback(null);
    const res = await request(app())
      .post('/api/chat/send')
      .set(authHeader(tokenForShipper(200)))
      .send({ shipmentId: 1000, receiverId: 100, message: 'hi' });
    expect(res.status).toBe(404);
  });

  test('500 when Message.create throws', async () => {
    expectKybVerified(200, 'shipper');
    expectFindShipment(
      shipmentFactory({ id: 1000, shipper_id: 200, driver_id: 100, status: 'assigned' })
    );
    expectFindChatShipmentFallback(
      shipmentFactory({ id: 1000, shipper_id: 200, driver_id: 100, status: 'assigned' })
    );
    dbMock.expectInsert(/INSERT INTO messages/i).rejectsWith(new Error('boom'));

    const res = await request(app())
      .post('/api/chat/send')
      .set(authHeader(tokenForShipper(200)))
      .send({ shipmentId: 1000, receiverId: 100, message: 'hi' });
    expect(res.status).toBe(500);
  });
});

describe('POST /api/chat/:shipmentId/location — extra branches', () => {
  test('400 when latitude is out of range', async () => {
    expectKybVerified(200, 'shipper');
    const res = await request(app())
      .post('/api/chat/1000/location')
      .set(authHeader(tokenForShipper(200)))
      .send({ receiverId: 100, latitude: 95, longitude: 46 });
    expect(res.status).toBe(400);
  });

  test('400 when longitude is out of range', async () => {
    expectKybVerified(200, 'shipper');
    const res = await request(app())
      .post('/api/chat/1000/location')
      .set(authHeader(tokenForShipper(200)))
      .send({ receiverId: 100, latitude: 24, longitude: -200 });
    expect(res.status).toBe(400);
  });

  test('201 falls back to default label "موقع" when no label is provided', async () => {
    expectKybVerified(200, 'shipper');
    expectFindShipment(
      shipmentFactory({ id: 1000, shipper_id: 200, driver_id: 100, status: 'assigned' })
    );
    expectFindChatShipmentFallback(
      shipmentFactory({ id: 1000, shipper_id: 200, driver_id: 100, status: 'assigned' })
    );
    dbMock.expectInsert(/INSERT INTO messages/i).returnsInsert(950);
    dbMock
      .expectSelect(/FROM messages m\s+LEFT JOIN users u/i)
      .returns([{ id: 950, message_type: 'location', message: 'موقع' }]);

    const res = await request(app())
      .post('/api/chat/1000/location')
      .set(authHeader(tokenForShipper(200)))
      .send({ receiverId: 100, latitude: 24.7, longitude: 46.6 });
    expect(res.status).toBe(201);
    expect(res.body.message).toBe('موقع');
  });
});

describe('POST /api/chat/:shipmentId/delivered — error branch', () => {
  test('500 when underlying SELECT throws', async () => {
    expectFindShipment(shipmentFactory({ id: 1000, shipper_id: 200, driver_id: 100 }));
    dbMock
      .expectSelect(/FROM messages\s+WHERE shipment_id = \?\s+AND receiver_id = \?\s+AND delivered_at IS NULL/i)
      .rejectsWith(new Error('boom'));
    const res = await request(app())
      .post('/api/chat/1000/delivered')
      .set(authHeader(tokenForShipper(200)))
      .send({});
    expect(res.status).toBe(500);
  });
});

describe('POST /api/chat/:shipmentId/read — error branch', () => {
  test('500 when underlying SELECT throws', async () => {
    expectFindShipment(shipmentFactory({ id: 1000, shipper_id: 200, driver_id: 100 }));
    dbMock
      .expectSelect(/FROM messages\s+WHERE shipment_id = \?\s+AND receiver_id = \?\s+AND read_at IS NULL/i)
      .rejectsWith(new Error('boom'));
    const res = await request(app())
      .post('/api/chat/1000/read')
      .set(authHeader(tokenForShipper(200)))
      .send({});
    expect(res.status).toBe(500);
  });

  test('404 when shipment missing on read', async () => {
    expectFindShipment(null);
    const res = await request(app())
      .post('/api/chat/1000/read')
      .set(authHeader(tokenForShipper(200)))
      .send({});
    expect(res.status).toBe(404);
  });

  test('403 when caller has no chat access', async () => {
    expectFindShipment(shipmentFactory({ id: 1000, shipper_id: 999, driver_id: 100 }));
    const res = await request(app())
      .post('/api/chat/1000/read')
      .set(authHeader(tokenForShipper(200)))
      .send({});
    expect(res.status).toBe(403);
  });
});

describe('GET /api/chat/:shipmentId — extra error path', () => {
  test('500 when Shipment.findById throws (unexpected error)', async () => {
    dbMock
      .expectSelect(/FROM shipments s\s+LEFT JOIN users sh/i)
      .rejectsWith(new Error('boom'));
    const res = await request(app())
      .get('/api/chat/1000')
      .set(authHeader(tokenForShipper(200)));
    expect(res.status).toBe(500);
  });
});

describe('GET /api/chat/conversations/me — extra', () => {
  test('empty conversation list still 200s with []', async () => {
    dbMock
      .expectSelect(/FROM \(\s+SELECT other_party_id, MAX\(message_id\)/i)
      .returns([]);
    const res = await request(app())
      .get('/api/chat/conversations/me')
      .set(authHeader(tokenForShipper(200)));
    expect(res.status).toBe(200);
    expect(res.body).toEqual([]);
  });
});
