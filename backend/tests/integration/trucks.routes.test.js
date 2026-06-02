/**
 * Integration tests for /api/trucks/* (truckController + truckRoutes).
 *
 * Truck model issues schema-bootstrap queries via ensureTruckClassificationSchema
 * and ensureTruckInsuranceSchema — both are stubbed in tests/setup.js. The
 * model still issues real CREATE TABLE/INFORMATION_SCHEMA probes through
 * pool.execute, so we route those.
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
const { userFactory, truckFactory } = require('../helpers/factories');
const { encryptText } = require('../../utils/encryption');

const app = () => buildTestApp({ routes: ['trucks'] });

const expectFindUser = (row) =>
  dbMock.expectSelect(/FROM users WHERE id = \?/i).returns(row ? [row] : []);

describe('GET /api/trucks/catalog', () => {
  test('200 returns the truck classification catalog payload', async () => {
    const res = await request(app()).get('/api/trucks/catalog');
    expect(res.status).toBe(200);
    expect(res.body).toMatchObject({ version: 1 });
    expect(Array.isArray(res.body.categories)).toBe(true);
    expect(Array.isArray(res.body.groups)).toBe(true);
    expect(Array.isArray(res.body.bodyTypes)).toBe(true);
    expect(res.body.categories[0]).toHaveProperty('id');
    expect(res.body.categories[0]).toHaveProperty('group');
  });
});

describe('POST /api/trucks/register', () => {
  const baseBody = {
    plate_number: 'AAA-1234',
    isthimara_no: 'ISTH-001',
    category: 'medium_double_5_10',
    axle_count: 2,
    body_type: 'box',
    payload_capacity: '5_10',
    max_weight_tons: 7.5,
  };

  test('401 without auth', async () => {
    const res = await request(app()).post('/api/trucks/register').send(baseBody);
    expect(res.status).toBe(401);
  });

  test('400 when express-validator fails (missing plate)', async () => {
    const res = await request(app())
      .post('/api/trucks/register')
      .set(authHeader(tokenForDriver(100)))
      .send({ ...baseBody, plate_number: '' });
    expect(res.status).toBe(400);
    expect(res.body.errors).toBeDefined();
  });

  test('400 when classification middleware rejects unknown category', async () => {
    const res = await request(app())
      .post('/api/trucks/register')
      .set(authHeader(tokenForDriver(100)))
      .send({ ...baseBody, category: 'invented' });
    expect(res.status).toBe(400);
  });

  test('403 when role is not driver', async () => {
    const res = await request(app())
      .post('/api/trucks/register')
      .set(authHeader(tokenForShipper(200)))
      .send(baseBody);
    expect(res.status).toBe(403);
    expect(res.body.message).toMatch(/فقط السائق/);
  });

  test('404 when driver user record is missing', async () => {
    expectFindUser(null);
    const res = await request(app())
      .post('/api/trucks/register')
      .set(authHeader(tokenForDriver(100)))
      .send(baseBody);
    expect(res.status).toBe(404);
  });

  test('400 when driver has reached the max number of trucks', async () => {
    expectFindUser(userFactory({ id: 100, role: 'driver' }));
    dbMock.expectSelect(/SELECT COUNT\(\*\) AS cnt FROM trucks/i).returns([{ cnt: 5 }]);
    const res = await request(app())
      .post('/api/trucks/register')
      .set(authHeader(tokenForDriver(100)))
      .send(baseBody);
    expect(res.status).toBe(400);
    expect(res.body.message).toMatch(/الأقصى/);
  });

  test('400 when plate number already in use', async () => {
    expectFindUser(userFactory({ id: 100, role: 'driver' }));
    dbMock.expectSelect(/SELECT COUNT\(\*\) AS cnt FROM trucks/i).returns([{ cnt: 0 }]);
    dbMock
      .expectSelect(/SELECT \* FROM trucks WHERE plate_number = \? LIMIT 1/i)
      .returns([{ id: 9 }]);
    const res = await request(app())
      .post('/api/trucks/register')
      .set(authHeader(tokenForDriver(100)))
      .send(baseBody);
    expect(res.status).toBe(400);
    expect(res.body.message).toMatch(/رقم اللوحة/);
  });

  test('201 happy path inserts the truck inside a transaction', async () => {
    expectFindUser(userFactory({ id: 100, role: 'driver' }));
    dbMock.expectSelect(/SELECT COUNT\(\*\) AS cnt FROM trucks/i).returns([{ cnt: 0 }]);
    dbMock
      .expectSelect(/SELECT \* FROM trucks WHERE plate_number = \? LIMIT 1/i)
      .returns([]);
    // Truck.create runs a transaction: first UPDATE (deactivate) is skipped
    // when the new truck isn't active, but for the first truck the controller
    // sets is_active=true → so we expect the UPDATE.
    dbMock.expectUpdate(/UPDATE trucks SET is_active = 0 WHERE user_id = \?/i).returnsAffected(0);
    dbMock.expectInsert(/INSERT INTO trucks/i).returnsInsert(9876);

    const res = await request(app())
      .post('/api/trucks/register')
      .set(authHeader(tokenForDriver(100)))
      .send(baseBody);
    expect(res.status).toBe(201);
    expect(res.body).toMatchObject({
      id: 9876,
      plate_number: 'AAA-1234',
      isthimara_no: 'ISTH-001',
      verification_status: 'pending',
      classification: { category: 'medium_double_5_10' },
    });
    expect(dbMock.transactionEvents).toEqual(['begin', 'commit', 'release']);
  });

  test('500 with rollback when insert fails', async () => {
    expectFindUser(userFactory({ id: 100, role: 'driver' }));
    dbMock.expectSelect(/SELECT COUNT\(\*\) AS cnt FROM trucks/i).returns([{ cnt: 0 }]);
    dbMock
      .expectSelect(/SELECT \* FROM trucks WHERE plate_number = \? LIMIT 1/i)
      .returns([]);
    dbMock.expectUpdate(/UPDATE trucks SET is_active = 0 WHERE user_id = \?/i).returnsAffected(0);
    dbMock.expectInsert(/INSERT INTO trucks/i).rejectsWith(new Error('boom'));
    const res = await request(app())
      .post('/api/trucks/register')
      .set(authHeader(tokenForDriver(100)))
      .send(baseBody);
    expect(res.status).toBe(500);
    expect(dbMock.transactionEvents).toContain('rollback');
  });
});

describe('GET /api/trucks/my', () => {
  test('401 without auth', async () => {
    const res = await request(app()).get('/api/trucks/my');
    expect(res.status).toBe(401);
  });

  test('403 when role is not driver', async () => {
    const res = await request(app())
      .get('/api/trucks/my')
      .set(authHeader(tokenForShipper(200)));
    expect(res.status).toBe(403);
  });

  test('200 returns trucks mapped with classification', async () => {
    dbMock
      .expectSelect(/FROM trucks t\s+LEFT JOIN compliance_documents cd/i)
      .returns([truckFactory({ id: 1 })]);
    const res = await request(app())
      .get('/api/trucks/my')
      .set(authHeader(tokenForDriver(100)));
    expect(res.status).toBe(200);
    expect(res.body[0].classification.category).toBe('medium_double_5_10');
  });

  test('falls back to the plain list when the insurance join query fails', async () => {
    dbMock
      .expectSelect(/FROM trucks t\s+LEFT JOIN compliance_documents cd/i)
      .rejectsWith(new Error('insurance schema missing'));
    dbMock.expectSelect(/SELECT \* FROM trucks WHERE user_id = \?/i).returns([truckFactory({ id: 2 })]);
    const res = await request(app())
      .get('/api/trucks/my')
      .set(authHeader(tokenForDriver(100)));
    expect(res.status).toBe(200);
    expect(res.body[0].insurance_document_id).toBeNull();
  });

  test('500 when both queries throw', async () => {
    dbMock
      .expectSelect(/FROM trucks t\s+LEFT JOIN compliance_documents cd/i)
      .rejectsWith(new Error('boom1'));
    dbMock
      .expectSelect(/SELECT \* FROM trucks WHERE user_id = \?/i)
      .rejectsWith(new Error('boom2'));
    const res = await request(app())
      .get('/api/trucks/my')
      .set(authHeader(tokenForDriver(100)));
    expect(res.status).toBe(500);
  });
});

describe('PATCH /api/trucks/:truckId/active', () => {
  test('403 when role is not driver', async () => {
    const res = await request(app())
      .patch('/api/trucks/9/active')
      .set(authHeader(tokenForShipper(200)));
    expect(res.status).toBe(403);
  });

  test('404 when truck is not owned by driver', async () => {
    dbMock
      .expectSelect(/SELECT id FROM trucks WHERE id = \? AND user_id = \?/i)
      .returns([]);
    const res = await request(app())
      .patch('/api/trucks/9/active')
      .set(authHeader(tokenForDriver(100)));
    expect(res.status).toBe(404);
    expect(dbMock.transactionEvents).toEqual(['begin', 'rollback', 'release']);
  });

  test('200 sets the active truck and returns refreshed list', async () => {
    dbMock
      .expectSelect(/SELECT id FROM trucks WHERE id = \? AND user_id = \?/i)
      .returns([{ id: 9 }]);
    dbMock.expectUpdate(/UPDATE trucks SET is_active = 0 WHERE user_id = \?/i).returnsAffected(2);
    dbMock
      .expectUpdate(/UPDATE trucks SET is_active = 1 WHERE id = \? AND user_id = \?/i)
      .returnsAffected(1);
    dbMock
      .expectSelect(/FROM trucks t\s+LEFT JOIN compliance_documents cd/i)
      .returns([truckFactory({ id: 9, is_active: 1 })]);

    const res = await request(app())
      .patch('/api/trucks/9/active')
      .set(authHeader(tokenForDriver(100)));
    expect(res.status).toBe(200);
    expect(res.body.data).toHaveLength(1);
    expect(dbMock.transactionEvents).toEqual(['begin', 'commit', 'release']);
  });

  test('500 when the transaction fails', async () => {
    dbMock
      .expectSelect(/SELECT id FROM trucks WHERE id = \? AND user_id = \?/i)
      .rejectsWith(new Error('boom'));
    const res = await request(app())
      .patch('/api/trucks/9/active')
      .set(authHeader(tokenForDriver(100)));
    expect(res.status).toBe(500);
    expect(dbMock.transactionEvents).toContain('rollback');
  });
});

describe('PUT /api/trucks/:truckId (update)', () => {
  test('400 when validator fails', async () => {
    const res = await request(app())
      .put('/api/trucks/9')
      .set(authHeader(tokenForDriver(100)))
      .send({ capacity_kg: -5 });
    expect(res.status).toBe(400);
  });

  test('403 when role is not driver', async () => {
    const res = await request(app())
      .put('/api/trucks/9')
      .set(authHeader(tokenForShipper(200)))
      .send({});
    expect(res.status).toBe(403);
  });

  test('404 when truck is missing', async () => {
    dbMock.expectSelect(/SELECT \* FROM trucks WHERE id = \?/i).returns([]);
    const res = await request(app())
      .put('/api/trucks/9')
      .set(authHeader(tokenForDriver(100)))
      .send({});
    expect(res.status).toBe(404);
  });

  test('403 when caller does not own the truck', async () => {
    dbMock
      .expectSelect(/SELECT \* FROM trucks WHERE id = \?/i)
      .returns([truckFactory({ id: 9, user_id: 999 })]);
    const res = await request(app())
      .put('/api/trucks/9')
      .set(authHeader(tokenForDriver(100)))
      .send({});
    expect(res.status).toBe(403);
  });

  test('400 when new plate number collides with another truck', async () => {
    dbMock
      .expectSelect(/SELECT \* FROM trucks WHERE id = \?/i)
      .returns([truckFactory({ id: 9, user_id: 100, plate_number: 'OLD' })]);
    dbMock
      .expectSelect(/SELECT \* FROM trucks WHERE plate_number = \? LIMIT 1/i)
      .returns([{ id: 11 }]);
    const res = await request(app())
      .put('/api/trucks/9')
      .set(authHeader(tokenForDriver(100)))
      .send({ plate_number: 'NEW' });
    expect(res.status).toBe(400);
  });

  test('200 happy path updates and returns the truck', async () => {
    dbMock
      .expectSelect(/SELECT \* FROM trucks WHERE id = \?/i)
      .returns([truckFactory({ id: 9, user_id: 100, is_active: 1 })]);
    // Inside Truck.update transaction:
    dbMock.expectSelect(/SELECT user_id FROM trucks WHERE id = \? LIMIT 1/i).returns([{ user_id: 100 }]);
    // is_active falls back to truthy → deactivate-others first
    dbMock.expectUpdate(/UPDATE trucks SET is_active = 0 WHERE user_id = \?/i).returnsAffected(2);
    dbMock.expectUpdate(/UPDATE trucks SET\s+plate_number = \?/i).returnsAffected(1);
    // Followed by findById to re-read
    dbMock.expectSelect(/SELECT \* FROM trucks WHERE id = \?/i).returns([truckFactory({ id: 9 })]);

    const res = await request(app())
      .put('/api/trucks/9')
      .set(authHeader(tokenForDriver(100)))
      .send({
        plate_number: 'AAA-1234',
        category: 'medium_double_5_10',
        axle_count: 2,
        body_type: 'box',
        payload_capacity: '5_10',
        max_weight_tons: 7.5,
      });
    expect(res.status).toBe(200);
    expect(res.body.id).toBe(9);
  });

  test('400 when classification validator fails', async () => {
    dbMock
      .expectSelect(/SELECT \* FROM trucks WHERE id = \?/i)
      .returns([truckFactory({ id: 9, user_id: 100 })]);
    // We send only a classification patch that the validator will reject.
    const res = await request(app())
      .put('/api/trucks/9')
      .set(authHeader(tokenForDriver(100)))
      .send({ category: 'mystery_category' });
    expect(res.status).toBe(400);
  });
});

describe('DELETE /api/trucks/:truckId', () => {
  test('404 when not found', async () => {
    dbMock.expectSelect(/SELECT \* FROM trucks WHERE id = \?/i).returns([]);
    const res = await request(app())
      .delete('/api/trucks/9')
      .set(authHeader(tokenForDriver(100)));
    expect(res.status).toBe(404);
  });

  test('403 when not owner', async () => {
    dbMock
      .expectSelect(/SELECT \* FROM trucks WHERE id = \?/i)
      .returns([truckFactory({ id: 9, user_id: 999 })]);
    const res = await request(app())
      .delete('/api/trucks/9')
      .set(authHeader(tokenForDriver(100)));
    expect(res.status).toBe(403);
  });

  test('200 marks the truck as rejected (soft delete)', async () => {
    dbMock
      .expectSelect(/SELECT \* FROM trucks WHERE id = \?/i)
      .returns([truckFactory({ id: 9, user_id: 100 })]);
    dbMock
      .expectUpdate(/UPDATE trucks SET verification_status = \? WHERE id = \?/i)
      .returnsAffected(1);
    const res = await request(app())
      .delete('/api/trucks/9')
      .set(authHeader(tokenForDriver(100)));
    expect(res.status).toBe(200);
  });
});

describe('Admin truck endpoints', () => {
  test('GET /admin/pending requires admin', async () => {
    const res = await request(app())
      .get('/api/trucks/admin/pending')
      .set(authHeader(tokenForDriver(100)));
    expect(res.status).toBe(403);
  });

  test('GET /admin/pending returns list for admin', async () => {
    dbMock
      .expectSelect(/SELECT \* FROM trucks WHERE verification_status = "pending"/i)
      .returns([truckFactory({ id: 1 })]);
    const res = await request(app())
      .get('/api/trucks/admin/pending')
      .set(authHeader(tokenForAdmin()));
    expect(res.status).toBe(200);
    expect(res.body).toHaveLength(1);
  });

  test('POST /admin/:truckId/verify requires admin', async () => {
    const res = await request(app())
      .post('/api/trucks/admin/9/verify')
      .set(authHeader(tokenForDriver(100)))
      .send({ status: 'verified' });
    expect(res.status).toBe(403);
  });

  test('POST /admin/:truckId/verify validates status', async () => {
    const res = await request(app())
      .post('/api/trucks/admin/9/verify')
      .set(authHeader(tokenForAdmin()))
      .send({ status: 'maybe' });
    expect(res.status).toBe(400);
  });

  test('POST /admin/:truckId/verify returns 404 when no rows updated', async () => {
    dbMock.expectUpdate(/UPDATE trucks SET verification_status = \?/i).returnsAffected(0);
    const res = await request(app())
      .post('/api/trucks/admin/9/verify')
      .set(authHeader(tokenForAdmin()))
      .send({ status: 'verified' });
    expect(res.status).toBe(404);
  });

  test('POST /admin/:truckId/verify happy path', async () => {
    dbMock.expectUpdate(/UPDATE trucks SET verification_status = \?/i).returnsAffected(1);
    const res = await request(app())
      .post('/api/trucks/admin/9/verify')
      .set(authHeader(tokenForAdmin()))
      .send({ status: 'verified' });
    expect(res.status).toBe(200);
  });
});

describe('POST /api/trucks/insurance & /:truckId/insurance', () => {
  test('400 when called without a truck context', async () => {
    const res = await request(app())
      .post('/api/trucks/insurance')
      .set(authHeader(tokenForDriver(100)));
    expect(res.status).toBe(400);
  });

  test('400 when file missing', async () => {
    const res = await request(app())
      .post('/api/trucks/9/insurance')
      .set(authHeader(tokenForDriver(100)))
      .send({});
    expect(res.status).toBe(400);
    expect(res.body.message).toMatch(/مطلوب/);
  });

  test('403 when not a driver', async () => {
    const res = await request(app())
      .post('/api/trucks/9/insurance')
      .set(authHeader(tokenForShipper(200)))
      .send({ document: 'insurance/9.pdf' });
    expect(res.status).toBe(403);
  });

  test('404 when truck not found', async () => {
    expectFindUser(userFactory({ id: 100, role: 'driver' }));
    dbMock.expectSelect(/SELECT \* FROM trucks WHERE id = \?/i).returns([]);
    const res = await request(app())
      .post('/api/trucks/9/insurance')
      .set(authHeader(tokenForDriver(100)))
      .send({ document: 'insurance/9.pdf' });
    expect(res.status).toBe(404);
  });

  test('201 stores compliance document with explicit expiry_date', async () => {
    expectFindUser(userFactory({ id: 100, role: 'driver' }));
    dbMock
      .expectSelect(/SELECT \* FROM trucks WHERE id = \?/i)
      .returns([truckFactory({ id: 9, user_id: 100 })]);
    dbMock.expectInsert(/INSERT INTO compliance_documents/i).returnsInsert(701);

    const res = await request(app())
      .post('/api/trucks/9/insurance')
      .set(authHeader(tokenForDriver(100)))
      .send({ document: 'insurance/9.pdf', expiry_date: '2030-01-01' });
    expect(res.status).toBe(201);
    expect(res.body.data).toMatchObject({
      document_id: 701,
      truck_id: 9,
      document_type: 'vehicle_insurance',
      expiry_date: '2030-01-01',
    });
  });
});
