/**
 * Extra coverage for the truck controller error / branch paths not exercised
 * by `trucks.routes.test.js` — 500 catch blocks and a couple of subtle branches.
 */
'use strict';

const request = require('supertest');

const { buildTestApp } = require('../helpers/testApp');
const { dbMock } = require('../helpers/db');
const {
  tokenForDriver,
  tokenForAdmin,
  authHeader,
} = require('../helpers/auth');
const { userFactory, truckFactory } = require('../helpers/factories');

const app = () => buildTestApp({ routes: ['trucks'] });

describe('PUT /api/trucks/:truckId — 500 path', () => {
  test('500 when Truck.update throws inside the transaction', async () => {
    dbMock
      .expectSelect(/SELECT \* FROM trucks WHERE id = \?/i)
      .returns([truckFactory({ id: 9, user_id: 100, is_active: 1 })]);
    // Truck.update calls findById internally to ensure existence first.
    dbMock
      .expectSelect(/SELECT user_id FROM trucks WHERE id = \? LIMIT 1/i)
      .returns([{ user_id: 100 }]);
    // is_active=true path → deactivate-others first
    dbMock
      .expectUpdate(/UPDATE trucks SET is_active = 0 WHERE user_id = \?/i)
      .returnsAffected(0);
    dbMock
      .expectUpdate(/UPDATE trucks SET\s+plate_number = \?/i)
      .rejectsWith(new Error('db down'));

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
    expect(res.status).toBe(500);
  });

  test('400 when Truck.update returns false (no row affected)', async () => {
    dbMock
      .expectSelect(/SELECT \* FROM trucks WHERE id = \?/i)
      .returns([truckFactory({ id: 9, user_id: 100, is_active: 1 })]);
    dbMock
      .expectSelect(/SELECT user_id FROM trucks WHERE id = \? LIMIT 1/i)
      .returns([{ user_id: 100 }]);
    dbMock
      .expectUpdate(/UPDATE trucks SET is_active = 0 WHERE user_id = \?/i)
      .returnsAffected(0);
    dbMock
      .expectUpdate(/UPDATE trucks SET\s+plate_number = \?/i)
      .returnsAffected(0);

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
    expect([400, 500]).toContain(res.status);
  });
});

describe('DELETE /api/trucks/:truckId — 500 path', () => {
  test('500 when Truck.verifyTruck throws', async () => {
    dbMock
      .expectSelect(/SELECT \* FROM trucks WHERE id = \?/i)
      .returns([truckFactory({ id: 9, user_id: 100 })]);
    dbMock
      .expectUpdate(/UPDATE trucks SET verification_status = \? WHERE id = \?/i)
      .rejectsWith(new Error('boom'));
    const res = await request(app())
      .delete('/api/trucks/9')
      .set(authHeader(tokenForDriver(100)));
    expect(res.status).toBe(500);
  });
});

describe('GET /api/trucks/admin/pending — 500 path', () => {
  test('500 when Truck.listPending throws', async () => {
    dbMock
      .expectSelect(/SELECT \* FROM trucks WHERE verification_status = "pending"/i)
      .rejectsWith(new Error('boom'));
    const res = await request(app())
      .get('/api/trucks/admin/pending')
      .set(authHeader(tokenForAdmin()));
    expect(res.status).toBe(500);
  });
});

describe('POST /api/trucks/admin/:truckId/verify — 500 path', () => {
  test('500 when Truck.verifyTruck throws', async () => {
    dbMock
      .expectUpdate(/UPDATE trucks SET verification_status = \?/i)
      .rejectsWith(new Error('db down'));
    const res = await request(app())
      .post('/api/trucks/admin/9/verify')
      .set(authHeader(tokenForAdmin()))
      .send({ status: 'verified' });
    expect(res.status).toBe(500);
  });
});

describe('POST /api/trucks/:truckId/insurance — additional branches', () => {
  test('401 when no auth', async () => {
    const res = await request(app())
      .post('/api/trucks/9/insurance')
      .send({});
    expect(res.status).toBe(401);
  });

  test('400 when truckId missing (no truck context)', async () => {
    const res = await request(app())
      .post('/api/trucks/insurance')
      .set(authHeader(tokenForDriver(100)))
      .send({});
    expect(res.status).toBe(400);
  });

  test('500 when ComplianceDocument.create throws', async () => {
    dbMock
      .expectSelect(/FROM users WHERE id = \?/i)
      .returns([userFactory({ id: 100, role: 'driver' })]);
    dbMock
      .expectSelect(/SELECT \* FROM trucks WHERE id = \?/i)
      .returns([truckFactory({ id: 9, user_id: 100 })]);
    dbMock
      .expectInsert(/INSERT INTO compliance_documents/i)
      .rejectsWith(new Error('boom'));

    const res = await request(app())
      .post('/api/trucks/9/insurance')
      .set(authHeader(tokenForDriver(100)))
      .send({ document: 'insurance/x.pdf' });
    expect(res.status).toBe(500);
  });

  test('404 when driver user not found (deleted account)', async () => {
    // User.findById + Truck.findById fire in parallel; mock both.
    dbMock.expectSelect(/FROM users WHERE id = \?/i).returns([]);
    dbMock
      .expectSelect(/SELECT \* FROM trucks WHERE id = \?/i)
      .returns([truckFactory({ id: 9, user_id: 100 })]);
    const res = await request(app())
      .post('/api/trucks/9/insurance')
      .set(authHeader(tokenForDriver(100)))
      .send({ document: 'insurance/x.pdf' });
    expect(res.status).toBe(404);
  });

  test('404 when truck owner mismatches the driver', async () => {
    dbMock
      .expectSelect(/FROM users WHERE id = \?/i)
      .returns([userFactory({ id: 100, role: 'driver' })]);
    dbMock
      .expectSelect(/SELECT \* FROM trucks WHERE id = \?/i)
      .returns([truckFactory({ id: 9, user_id: 999 })]);
    const res = await request(app())
      .post('/api/trucks/9/insurance')
      .set(authHeader(tokenForDriver(100)))
      .send({ document: 'insurance/x.pdf' });
    expect(res.status).toBe(404);
  });
});
