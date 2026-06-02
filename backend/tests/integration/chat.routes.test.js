/**
 * Integration tests for /api/chat/* (chatController + chatRoutes + Message
 * model). Exercises send/get/read receipts/media/location flows.
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
const { userFactory, shipmentFactory } = require('../helpers/factories');

const app = () => buildTestApp({ routes: ['chat'] });

const expectKybVerified = (id, role) =>
  dbMock
    .expectSelect(/FROM users WHERE id = \?/i)
    .returns([userFactory({ id, role, verification_status: 'verified' })]);

const expectFindShipment = (row) =>
  dbMock.expectSelect(/FROM shipments s\s+LEFT JOIN users sh/i).returns(row ? [row] : []);

describe('GET /api/chat/:shipmentId', () => {
  test('401 without auth', async () => {
    const res = await request(app()).get('/api/chat/1000');
    expect(res.status).toBe(401);
  });

  test('404 when shipment missing', async () => {
    expectFindShipment(null);
    const res = await request(app())
      .get('/api/chat/1000')
      .set(authHeader(tokenForShipper(200)));
    expect(res.status).toBe(404);
  });

  test('403 when caller is neither shipper nor driver', async () => {
    expectFindShipment(shipmentFactory({ id: 1000, shipper_id: 200, driver_id: 100 }));
    const res = await request(app())
      .get('/api/chat/1000')
      .set(authHeader(tokenForShipper(999)));
    expect(res.status).toBe(403);
  });

  test('200 returns list with enriched preview and presigned URLs', async () => {
    expectFindShipment(shipmentFactory({ id: 1000, shipper_id: 200, driver_id: 100 }));
    dbMock
      .expectSelect(/FROM messages m\s+LEFT JOIN users u ON u.id = m.sender_id\s+WHERE m.shipment_id = \?/i)
      .returns([
        {
          id: 1,
          shipment_id: 1000,
          sender_id: 100,
          receiver_id: 200,
          message: 'hi',
          message_type: 'text',
          media_key: null,
          thumbnail_key: null,
          sender_profile_image_key: 'profile/a.jpg',
        },
        {
          id: 2,
          shipment_id: 1000,
          sender_id: 200,
          receiver_id: 100,
          message_type: 'image',
          media_key: 'media/x.jpg',
          media_mime_type: 'image/jpeg',
          thumbnail_key: null,
        },
      ]);

    const res = await request(app())
      .get('/api/chat/1000')
      .set(authHeader(tokenForShipper(200)));
    expect(res.status).toBe(200);
    expect(res.body).toHaveLength(2);
    expect(res.body[0].last_preview).toBe('hi');
    expect(res.body[1].last_preview).toBe('صورة');
    expect(res.body[1].media_url).toMatch(/test-s3.local/);
    expect(res.body[0].sender_profile_image_url).toMatch(/test-s3.local/);
  });

  test('500 when message lookup fails', async () => {
    expectFindShipment(shipmentFactory({ id: 1000, shipper_id: 200, driver_id: 100 }));
    dbMock
      .expectSelect(/FROM messages m\s+LEFT JOIN users u/i)
      .rejectsWith(new Error('boom'));
    const res = await request(app())
      .get('/api/chat/1000')
      .set(authHeader(tokenForShipper(200)));
    expect(res.status).toBe(500);
  });
});

describe('POST /api/chat/send', () => {
  test('400 when validator fails', async () => {
    expectKybVerified(200, 'shipper');
    const res = await request(app())
      .post('/api/chat/send')
      .set(authHeader(tokenForShipper(200)))
      .send({ shipmentId: 'x', message: '' });
    expect(res.status).toBe(400);
  });

  test('400 when shipment status is not in allowed list', async () => {
    expectKybVerified(200, 'shipper');
    expectFindShipment(
      shipmentFactory({ id: 1000, shipper_id: 200, driver_id: 100, status: 'bidding' })
    );
    expectFindChatShipmentFallback(null);
    const res = await request(app())
      .post('/api/chat/send')
      .set(authHeader(tokenForShipper(200)))
      .send({ shipmentId: 1000, receiverId: 100, message: 'hi' });
    expect(res.status).toBe(400);
    expect(res.body.message).toMatch(/قبول العرض/);
  });

  test('403 when sender is neither shipper nor driver of the shipment', async () => {
    expectKybVerified(200, 'shipper');
    expectFindShipment(
      shipmentFactory({ id: 1000, shipper_id: 999, driver_id: 100, status: 'assigned' })
    );
    expectFindChatShipmentFallback(null);
    const res = await request(app())
      .post('/api/chat/send')
      .set(authHeader(tokenForShipper(200)))
      .send({ shipmentId: 1000, receiverId: 100, message: 'hi' });
    expect(res.status).toBe(403);
  });

  test('201 sends message and returns enriched payload', async () => {
    expectKybVerified(200, 'shipper');
    expectFindShipment(
      shipmentFactory({ id: 1000, shipper_id: 200, driver_id: 100, status: 'assigned' })
    );
    expectFindChatShipmentFallback(
      shipmentFactory({ id: 1000, shipper_id: 200, driver_id: 100, status: 'assigned' })
    );
    dbMock.expectInsert(/INSERT INTO messages/i).returnsInsert(900);
    dbMock
      .expectSelect(/FROM messages m\s+LEFT JOIN users u/i)
      .returns([
        {
          id: 900,
          shipment_id: 1000,
          sender_id: 200,
          receiver_id: 100,
          message: 'hi',
          message_type: 'text',
        },
      ]);

    const res = await request(app())
      .post('/api/chat/send')
      .set(authHeader(tokenForShipper(200)))
      .send({ shipmentId: 1000, receiverId: 100, message: '  hi  ' });
    expect(res.status).toBe(201);
    expect(res.body).toMatchObject({ id: 900, message: 'hi' });
  });
});

describe('POST /api/chat/:shipmentId/location', () => {
  test('400 when validator fails', async () => {
    expectKybVerified(200, 'shipper');
    const res = await request(app())
      .post('/api/chat/1000/location')
      .set(authHeader(tokenForShipper(200)))
      .send({ receiverId: 'x', latitude: 100, longitude: 0 });
    expect(res.status).toBe(400);
  });

  test('201 sends a location message', async () => {
    expectKybVerified(200, 'shipper');
    expectFindShipment(
      shipmentFactory({ id: 1000, shipper_id: 200, driver_id: 100, status: 'assigned' })
    );
    expectFindChatShipmentFallback(
      shipmentFactory({ id: 1000, shipper_id: 200, driver_id: 100, status: 'assigned' })
    );
    dbMock.expectInsert(/INSERT INTO messages/i).returnsInsert(901);
    dbMock
      .expectSelect(/FROM messages m\s+LEFT JOIN users u/i)
      .returns([
        {
          id: 901,
          message_type: 'location',
          location_label: 'الرياض',
        },
      ]);
    const res = await request(app())
      .post('/api/chat/1000/location')
      .set(authHeader(tokenForShipper(200)))
      .send({ receiverId: 100, latitude: 24.7, longitude: 46.6, label: 'الرياض' });
    expect(res.status).toBe(201);
  });
});

describe('POST /api/chat/:shipmentId/delivered & /:shipmentId/read', () => {
  test('404 when shipment missing for delivered', async () => {
    expectFindShipment(null);
    const res = await request(app())
      .post('/api/chat/1000/delivered')
      .set(authHeader(tokenForShipper(200)))
      .send({});
    expect(res.status).toBe(404);
  });

  test('403 when caller has no chat access', async () => {
    expectFindShipment(shipmentFactory({ id: 1000, shipper_id: 999, driver_id: 100 }));
    const res = await request(app())
      .post('/api/chat/1000/delivered')
      .set(authHeader(tokenForShipper(200)))
      .send({});
    expect(res.status).toBe(403);
  });

  test('200 returns 0 when no pending deliveries', async () => {
    expectFindShipment(shipmentFactory({ id: 1000, shipper_id: 200, driver_id: 100 }));
    dbMock
      .expectSelect(/FROM messages\s+WHERE shipment_id = \?\s+AND receiver_id = \?\s+AND delivered_at IS NULL/i)
      .returns([]);
    const res = await request(app())
      .post('/api/chat/1000/delivered')
      .set(authHeader(tokenForShipper(200)))
      .send({});
    expect(res.status).toBe(200);
    expect(res.body.updated).toBe(0);
  });

  test('200 marks pending messages delivered + fetches updated receipts', async () => {
    expectFindShipment(shipmentFactory({ id: 1000, shipper_id: 200, driver_id: 100 }));
    dbMock
      .expectSelect(/FROM messages\s+WHERE shipment_id = \?\s+AND receiver_id = \?\s+AND delivered_at IS NULL/i)
      .returns([{ id: 1 }, { id: 2 }]);
    dbMock
      .expectUpdate(/UPDATE messages\s+SET delivered_at = COALESCE\(delivered_at, \?\)/i)
      .returnsAffected(2);
    dbMock
      .expectSelect(/SELECT id, shipment_id, sender_id, receiver_id, delivered_at, read_at/i)
      .returns([
        { id: 1, shipment_id: 1000, sender_id: 100, receiver_id: 200 },
        { id: 2, shipment_id: 1000, sender_id: 100, receiver_id: 200 },
      ]);
    const res = await request(app())
      .post('/api/chat/1000/delivered')
      .set(authHeader(tokenForShipper(200)))
      .send({ messageIds: [1, 2] });
    expect(res.status).toBe(200);
    expect(res.body.updated).toBe(2);
  });

  test('200 marks messages as read', async () => {
    expectFindShipment(shipmentFactory({ id: 1000, shipper_id: 200, driver_id: 100 }));
    dbMock
      .expectSelect(/FROM messages\s+WHERE shipment_id = \?\s+AND receiver_id = \?\s+AND read_at IS NULL/i)
      .returns([{ id: 5 }]);
    dbMock
      .expectUpdate(/UPDATE messages\s+SET delivered_at = COALESCE\(delivered_at, \?\)/i)
      .returnsAffected(1);
    dbMock
      .expectSelect(/SELECT id, shipment_id, sender_id, receiver_id, delivered_at, read_at/i)
      .returns([{ id: 5, sender_id: 100 }]);

    const res = await request(app())
      .post('/api/chat/1000/read')
      .set(authHeader(tokenForShipper(200)))
      .send({ messageIds: [5] });
    expect(res.status).toBe(200);
    expect(res.body.updated).toBe(1);
  });
});

describe('POST /api/chat/:shipmentId/media', () => {
  test('400 when validator fails', async () => {
    expectKybVerified(200, 'shipper');
    const res = await request(app())
      .post('/api/chat/1000/media')
      .set(authHeader(tokenForShipper(200)))
      .send({ receiverId: 'x' });
    expect(res.status).toBe(400);
  });

  test('400 when no file uploaded', async () => {
    expectKybVerified(200, 'shipper');
    const res = await request(app())
      .post('/api/chat/1000/media')
      .set(authHeader(tokenForShipper(200)))
      .send({ receiverId: 100 });
    expect(res.status).toBe(400);
  });

  test('201 sends an image message', async () => {
    expectKybVerified(200, 'shipper');
    expectFindShipment(
      shipmentFactory({ id: 1000, shipper_id: 200, driver_id: 100, status: 'assigned' })
    );
    expectFindChatShipmentFallback(
      shipmentFactory({ id: 1000, shipper_id: 200, driver_id: 100, status: 'assigned' })
    );
    dbMock.expectInsert(/INSERT INTO messages/i).returnsInsert(902);
    dbMock
      .expectSelect(/FROM messages m\s+LEFT JOIN users u/i)
      .returns([
        {
          id: 902,
          message_type: 'image',
          media_key: 'chat/img.jpg',
          media_mime_type: 'image/jpeg',
        },
      ]);
    const res = await request(app())
      .post('/api/chat/1000/media')
      .set(authHeader(tokenForShipper(200)))
      .send({
        receiverId: 100,
        media: {
          key: 'chat/img.jpg',
          mimetype: 'image/jpeg',
          originalname: 'pic.jpg',
          size: 1234,
        },
      });
    expect(res.status).toBe(201);
    expect(res.body.media_url).toMatch(/test-s3.local/);
  });
});

describe('GET /api/chat/conversations/me', () => {
  test('401 without auth', async () => {
    const res = await request(app()).get('/api/chat/conversations/me');
    expect(res.status).toBe(401);
  });

  test('200 returns conversation summaries with enriched profile images', async () => {
    dbMock
      .expectSelect(/FROM \(\s+SELECT other_party_id, MAX\(message_id\)/i)
      .returns([
        {
          other_party_id: 100,
          shipment_id: 1000,
          last_message: 'hi',
          last_message_type: 'text',
          other_party_profile_image_key: 'profile/d.jpg',
        },
      ]);
    const res = await request(app())
      .get('/api/chat/conversations/me')
      .set(authHeader(tokenForShipper(200)));
    expect(res.status).toBe(200);
    expect(res.body[0].other_party_profile_image_url).toMatch(/test-s3.local/);
  });

  test('500 when query fails', async () => {
    dbMock
      .expectSelect(/FROM \(\s+SELECT other_party_id, MAX\(message_id\)/i)
      .rejectsWith(new Error('boom'));
    const res = await request(app())
      .get('/api/chat/conversations/me')
      .set(authHeader(tokenForShipper(200)));
    expect(res.status).toBe(500);
  });
});

// ------- helpers -------
function expectFindChatShipmentFallback(row) {
  return dbMock
    .expectSelect(/FROM shipments\s+WHERE \(\s+\(shipper_id = \? AND driver_id = \?\)/i)
    .returns(row ? [row] : []);
}
