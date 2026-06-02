/**
 * Integration tests for /api/conversations/* (conversationController +
 * Conversation model). The model performs schema bootstrap on every call —
 * we route those INFORMATION_SCHEMA probes through dbMock.route so each test
 * focuses on the business SQL.
 */
'use strict';

const request = require('supertest');

const { buildTestApp } = require('../helpers/testApp');
const { dbMock } = require('../helpers/db');

const app = () => buildTestApp({ routes: ['conversations'] });

const stubSchemaBootstrap = () => {
  // ensureConversationSchema(): tableExists → 1, columnExists × 2 → 1, indexExists → 1,
  // then CREATE TABLE IF NOT EXISTS conversation_participants → []
  dbMock
    .route(/INFORMATION_SCHEMA/i, () => [[{ count: 1 }], { fieldCount: 0 }])
    .route(/^CREATE TABLE/i, () => [[], { fieldCount: 0 }])
    .route(/^ALTER TABLE/i, () => [[], { fieldCount: 0 }]);
};

describe('POST /api/conversations/get-or-create', () => {
  test('400 when sender_id is missing', async () => {
    const res = await request(app())
      .post('/api/conversations/get-or-create')
      .send({ receiver_id: 5 });
    expect(res.status).toBe(400);
  });

  test('400 when sender_id and receiver_id are the same', async () => {
    stubSchemaBootstrap();
    const res = await request(app())
      .post('/api/conversations/get-or-create')
      .send({ sender_id: 7, receiver_id: 7 });
    expect(res.status).toBe(400);
    expect(res.body.message).toMatch(/نفس المستخدم/);
  });

  test('200 returns existing conversation', async () => {
    stubSchemaBootstrap();
    dbMock
      .expectSelect(/FROM conversations\s+WHERE conversation_key = \?/i)
      .returns([{ conversation_id: 555 }]);

    const res = await request(app())
      .post('/api/conversations/get-or-create')
      .send({ sender_id: 7, receiver_id: 8 });
    expect(res.status).toBe(200);
    expect(res.body).toEqual({ conversation_id: 555, created: false });
    expect(dbMock.transactionEvents).toEqual(['begin', 'commit', 'release']);
  });

  test('201 creates a new direct conversation', async () => {
    stubSchemaBootstrap();
    dbMock.expectSelect(/FROM conversations\s+WHERE conversation_key/i).returns([]);
    dbMock.expectInsert(/INSERT INTO conversations \(conversation_key, type\)/i).returnsInsert(700);
    dbMock
      .expectInsert(/INSERT INTO conversation_participants/i)
      .returnsInsert(0, 2);

    const res = await request(app())
      .post('/api/conversations/get-or-create')
      .send({ sender_id: 9, receiver_id: 10 });
    expect(res.status).toBe(201);
    expect(res.body).toEqual({ conversation_id: 700, created: true });
    expect(dbMock.transactionEvents).toEqual(['begin', 'commit', 'release']);
  });

  test('recovers from a duplicate-key race by re-reading', async () => {
    stubSchemaBootstrap();
    dbMock.expectSelect(/FROM conversations\s+WHERE conversation_key/i).returns([]);
    const dup = Object.assign(new Error('dup'), { code: 'ER_DUP_ENTRY' });
    dbMock.expectInsert(/INSERT INTO conversations \(conversation_key, type\)/i).rejectsWith(dup);
    dbMock
      .expectSelect(/FROM conversations\s+WHERE conversation_key/i)
      .returns([{ conversation_id: 800 }]);

    const res = await request(app())
      .post('/api/conversations/get-or-create')
      .send({ sender_id: 9, receiver_id: 10 });
    expect(res.status).toBe(200);
    expect(res.body).toEqual({ conversation_id: 800, created: false });
  });

  test('500 when an unexpected error escapes', async () => {
    stubSchemaBootstrap();
    dbMock
      .expectSelect(/FROM conversations\s+WHERE conversation_key/i)
      .rejectsWith(new Error('boom'));
    const res = await request(app())
      .post('/api/conversations/get-or-create')
      .send({ sender_id: 9, receiver_id: 10 });
    expect(res.status).toBe(500);
  });
});

describe('POST /api/conversations', () => {
  test('400 when message body missing', async () => {
    const res = await request(app())
      .post('/api/conversations')
      .send({ shipmentId: 1, senderId: 2, receiverId: 3 });
    expect(res.status).toBe(400);
  });

  test('201 persists a message tied to a shipment', async () => {
    stubSchemaBootstrap();
    dbMock.expectInsert(/INSERT INTO conversations/i).returnsInsert(42);

    const res = await request(app())
      .post('/api/conversations')
      .send({ shipmentId: 1, senderId: 2, receiverId: 3, message: 'مرحبا' });
    expect(res.status).toBe(201);
    expect(res.body.id).toBe(42);
  });

  test('500 when insert fails', async () => {
    stubSchemaBootstrap();
    dbMock.expectInsert(/INSERT INTO conversations/i).rejectsWith(new Error('boom'));
    const res = await request(app())
      .post('/api/conversations')
      .send({ shipmentId: 1, senderId: 2, receiverId: 3, message: 'مرحبا' });
    expect(res.status).toBe(500);
  });
});

describe('GET /api/conversations/shipment/:shipmentId', () => {
  test('200 returns message list', async () => {
    stubSchemaBootstrap();
    dbMock
      .expectSelect(/FROM conversations WHERE shipment_id = \?/i)
      .returns([{ id: 1, message: 'hi' }]);

    const res = await request(app()).get('/api/conversations/shipment/1');
    expect(res.status).toBe(200);
    expect(res.body).toEqual([{ id: 1, message: 'hi' }]);
  });

  test('500 when select fails', async () => {
    stubSchemaBootstrap();
    dbMock
      .expectSelect(/FROM conversations WHERE shipment_id = \?/i)
      .rejectsWith(new Error('boom'));
    const res = await request(app()).get('/api/conversations/shipment/1');
    expect(res.status).toBe(500);
  });
});
