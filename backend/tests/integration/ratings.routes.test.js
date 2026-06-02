/**
 * Integration tests for /api/ratings/* (ratingController + ratingRoutes).
 *
 * The KYB middleware queries `users.verification_status`; we route those
 * lookups through dbMock so tests focus on rating-specific SQL. Notification
 * model writes are absorbed by the global mock (see tests/setup.js).
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
  shipmentFactory,
} = require('../helpers/factories');
const Notification = require('../../models/Notification');

const app = () => buildTestApp({ routes: ['ratings'] });

const expectKybVerified = (id, role = 'driver') =>
  dbMock
    .expectSelect(/FROM users WHERE id = \?/i)
    .returns([userFactory({ id, role, verification_status: 'verified' })]);

const expectFindShipment = (row) =>
  dbMock.expectSelect(/FROM shipments s\s+LEFT JOIN users sh/i).returns(row ? [row] : []);

describe('POST /api/ratings', () => {
  test('401 without auth', async () => {
    const res = await request(app()).post('/api/ratings').send({});
    expect(res.status).toBe(401);
  });

  test('400 when express-validator fails', async () => {
    expectKybVerified(100, 'driver');
    const res = await request(app())
      .post('/api/ratings')
      .set(authHeader(tokenForDriver(100)))
      .send({ shipment_id: 'x', rated_id: -1, stars: 10 });
    expect(res.status).toBe(400);
  });

  test('400 when rater rates themselves', async () => {
    expectKybVerified(100, 'driver');
    const res = await request(app())
      .post('/api/ratings')
      .set(authHeader(tokenForDriver(100)))
      .send({ shipment_id: 1, rated_id: 100, stars: 5 });
    expect(res.status).toBe(400);
    expect(res.body.message).toMatch(/حسابك/);
  });

  test('404 when shipment missing', async () => {
    expectKybVerified(100, 'driver');
    expectFindShipment(null);
    const res = await request(app())
      .post('/api/ratings')
      .set(authHeader(tokenForDriver(100)))
      .send({ shipment_id: 1, rated_id: 200, stars: 4 });
    expect(res.status).toBe(404);
  });

  test('400 when shipment is not delivered yet', async () => {
    expectKybVerified(100, 'driver');
    expectFindShipment(shipmentFactory({ id: 1, status: 'bidding' }));
    const res = await request(app())
      .post('/api/ratings')
      .set(authHeader(tokenForDriver(100)))
      .send({ shipment_id: 1, rated_id: 200, stars: 4 });
    expect(res.status).toBe(400);
    expect(res.body.message).toMatch(/تكتمل/);
  });

  test('403 when a driver tries to rate someone else\'s shipment', async () => {
    expectKybVerified(100, 'driver');
    expectFindShipment(
      shipmentFactory({ id: 1, status: 'delivered', driver_id: 999, shipper_id: 200 })
    );
    const res = await request(app())
      .post('/api/ratings')
      .set(authHeader(tokenForDriver(100)))
      .send({ shipment_id: 1, rated_id: 200, stars: 4 });
    expect(res.status).toBe(403);
  });

  test('400 when driver rates a non-shipper id', async () => {
    expectKybVerified(100, 'driver');
    expectFindShipment(
      shipmentFactory({ id: 1, status: 'delivered', driver_id: 100, shipper_id: 200 })
    );
    const res = await request(app())
      .post('/api/ratings')
      .set(authHeader(tokenForDriver(100)))
      .send({ shipment_id: 1, rated_id: 999, stars: 4 });
    expect(res.status).toBe(400);
    expect(res.body.message).toMatch(/المقيم/);
  });

  test('403 when a shipper rates a shipment that isn\'t theirs', async () => {
    expectKybVerified(200, 'shipper');
    expectFindShipment(
      shipmentFactory({ id: 1, status: 'delivered', driver_id: 100, shipper_id: 999 })
    );
    const res = await request(app())
      .post('/api/ratings')
      .set(authHeader(tokenForShipper(200)))
      .send({ shipment_id: 1, rated_id: 100, stars: 4 });
    expect(res.status).toBe(403);
  });

  test('400 when shipper rates a non-driver id', async () => {
    expectKybVerified(200, 'shipper');
    expectFindShipment(
      shipmentFactory({ id: 1, status: 'delivered', driver_id: 100, shipper_id: 200 })
    );
    const res = await request(app())
      .post('/api/ratings')
      .set(authHeader(tokenForShipper(200)))
      .send({ shipment_id: 1, rated_id: 999, stars: 4 });
    expect(res.status).toBe(400);
  });

  test('400 when rater already has a rating for this shipment', async () => {
    expectKybVerified(100, 'driver');
    expectFindShipment(
      shipmentFactory({ id: 1, status: 'delivered', driver_id: 100, shipper_id: 200 })
    );
    dbMock
      .expectSelect(/FROM ratings\s+WHERE shipment_id = \? AND rater_id = \?/i)
      .returns([{ id: 99 }]);

    const res = await request(app())
      .post('/api/ratings')
      .set(authHeader(tokenForDriver(100)))
      .send({ shipment_id: 1, rated_id: 200, stars: 4 });
    expect(res.status).toBe(400);
    expect(res.body.message).toMatch(/بالفعل/);
  });

  test('201 inserts the rating, returns formatted summary, fires notification', async () => {
    expectKybVerified(100, 'driver');
    expectFindShipment(
      shipmentFactory({ id: 1, status: 'delivered', driver_id: 100, shipper_id: 200 })
    );
    dbMock
      .expectSelect(/FROM ratings\s+WHERE shipment_id = \? AND rater_id = \?/i)
      .returns([]);
    dbMock.expectInsert(/INSERT INTO ratings/i).returnsInsert(7777);
    dbMock
      .expectSelect(/AVG\(CASE WHEN stars BETWEEN 1 AND 5/i)
      .returns([{ average_rating: 4.3333, total_ratings: 3 }]);

    const res = await request(app())
      .post('/api/ratings')
      .set(authHeader(tokenForDriver(100)))
      .send({ shipment_id: 1, rated_id: 200, stars: 5, comment: '  ممتاز  ' });

    expect(res.status).toBe(201);
    expect(res.body).toMatchObject({
      id: 7777,
      shipment_id: 1,
      rater_id: 100,
      rated_id: 200,
      stars: 5,
      comment: 'ممتاز',
      average_rating: '4.33',
      total_ratings: 3,
    });
    expect(Notification.create).toHaveBeenCalled();
  });

  test('500 when ratings INSERT fails', async () => {
    expectKybVerified(100, 'driver');
    expectFindShipment(
      shipmentFactory({ id: 1, status: 'delivered', driver_id: 100, shipper_id: 200 })
    );
    dbMock
      .expectSelect(/FROM ratings\s+WHERE shipment_id = \? AND rater_id = \?/i)
      .returns([]);
    dbMock.expectInsert(/INSERT INTO ratings/i).rejectsWith(new Error('boom'));
    const res = await request(app())
      .post('/api/ratings')
      .set(authHeader(tokenForDriver(100)))
      .send({ shipment_id: 1, rated_id: 200, stars: 5 });
    expect(res.status).toBe(500);
  });
});

describe('GET /api/ratings/user/:userId', () => {
  test('400 when userId is invalid', async () => {
    const res = await request(app()).get('/api/ratings/user/0');
    expect(res.status).toBe(400);
  });

  test('404 when user does not exist', async () => {
    dbMock.expectSelect(/FROM users WHERE id = \?/i).returns([]);
    const res = await request(app()).get('/api/ratings/user/100');
    expect(res.status).toBe(404);
  });

  test('200 returns ratings + summary + rated_profile', async () => {
    dbMock
      .expectSelect(/FROM users WHERE id = \?/i)
      .returns([userFactory({ id: 100, full_name: 'سائق' })]);
    dbMock.expectSelect(/FROM ratings\s+WHERE rated_id = \?/i).returns([{ id: 1, stars: 5 }]);
    dbMock
      .expectSelect(/AVG\(CASE WHEN stars BETWEEN/i)
      .returns([{ average_rating: 4.7, total_ratings: 10 }]);
    dbMock
      .expectSelect(/FROM users WHERE id = \?/i)
      .returns([userFactory({ id: 100, full_name: 'سائق', role: 'driver' })]);

    const res = await request(app()).get('/api/ratings/user/100');
    expect(res.status).toBe(200);
    expect(res.body).toMatchObject({
      user_id: 100,
      average_rating: '4.70',
      total_ratings: 10,
      ratings: [{ id: 1, stars: 5 }],
      rated_profile: { id: 100, role: 'driver' },
    });
  });

  test('500 on db error', async () => {
    dbMock.expectSelect(/FROM users WHERE id = \?/i).rejectsWith(new Error('boom'));
    const res = await request(app()).get('/api/ratings/user/100');
    expect(res.status).toBe(500);
  });
});

describe('PUT /api/ratings/:ratingId', () => {
  test('401 without auth', async () => {
    const res = await request(app())
      .put('/api/ratings/1')
      .send({ stars: 4 });
    expect(res.status).toBe(401);
  });

  test('400 when validator rejects stars', async () => {
    expectKybVerified(100, 'driver');
    const res = await request(app())
      .put('/api/ratings/1')
      .set(authHeader(tokenForDriver(100)))
      .send({ stars: 99 });
    expect(res.status).toBe(400);
  });

  test('400 when ratingId is not a positive int', async () => {
    expectKybVerified(100, 'driver');
    const res = await request(app())
      .put('/api/ratings/0')
      .set(authHeader(tokenForDriver(100)))
      .send({ stars: 4 });
    expect(res.status).toBe(400);
  });

  test('404 when rating does not exist', async () => {
    expectKybVerified(100, 'driver');
    dbMock.expectSelect(/FROM ratings\s+WHERE id = \?/i).returns([]);
    const res = await request(app())
      .put('/api/ratings/123')
      .set(authHeader(tokenForDriver(100)))
      .send({ stars: 4 });
    expect(res.status).toBe(404);
  });

  test('403 when caller is not the original rater', async () => {
    expectKybVerified(100, 'driver');
    dbMock.expectSelect(/FROM ratings\s+WHERE id = \?/i).returns([{ id: 1, rater_id: 999 }]);
    const res = await request(app())
      .put('/api/ratings/1')
      .set(authHeader(tokenForDriver(100)))
      .send({ stars: 4 });
    expect(res.status).toBe(403);
  });

  test('200 updates the rating', async () => {
    expectKybVerified(100, 'driver');
    dbMock.expectSelect(/FROM ratings\s+WHERE id = \?/i).returns([{ id: 1, rater_id: 100 }]);
    dbMock.expectUpdate(/UPDATE ratings SET stars = \?/i).returnsAffected(1);
    const res = await request(app())
      .put('/api/ratings/1')
      .set(authHeader(tokenForDriver(100)))
      .send({ stars: 4, comment: 'good' });
    expect(res.status).toBe(200);
  });

  test('404 when the UPDATE affects no rows', async () => {
    expectKybVerified(100, 'driver');
    dbMock.expectSelect(/FROM ratings\s+WHERE id = \?/i).returns([{ id: 1, rater_id: 100 }]);
    dbMock.expectUpdate(/UPDATE ratings SET stars = \?/i).returnsAffected(0);
    const res = await request(app())
      .put('/api/ratings/1')
      .set(authHeader(tokenForDriver(100)))
      .send({ stars: 4 });
    expect(res.status).toBe(404);
  });
});

describe('DELETE /api/ratings/:ratingId', () => {
  test('400 when ratingId invalid', async () => {
    expectKybVerified(100, 'driver');
    const res = await request(app())
      .delete('/api/ratings/0')
      .set(authHeader(tokenForDriver(100)));
    expect(res.status).toBe(400);
  });

  test('404 when rating does not exist', async () => {
    expectKybVerified(100, 'driver');
    dbMock.expectSelect(/FROM ratings\s+WHERE id = \?/i).returns([]);
    const res = await request(app())
      .delete('/api/ratings/1')
      .set(authHeader(tokenForDriver(100)));
    expect(res.status).toBe(404);
  });

  test('403 when caller is not the rater', async () => {
    expectKybVerified(100, 'driver');
    dbMock.expectSelect(/FROM ratings\s+WHERE id = \?/i).returns([{ id: 1, rater_id: 999 }]);
    const res = await request(app())
      .delete('/api/ratings/1')
      .set(authHeader(tokenForDriver(100)));
    expect(res.status).toBe(403);
  });

  test('200 deletes the rating', async () => {
    expectKybVerified(100, 'driver');
    dbMock.expectSelect(/FROM ratings\s+WHERE id = \?/i).returns([{ id: 1, rater_id: 100 }]);
    dbMock.expectDelete(/DELETE FROM ratings WHERE id = \?/i).returnsAffected(1);
    const res = await request(app())
      .delete('/api/ratings/1')
      .set(authHeader(tokenForDriver(100)));
    expect(res.status).toBe(200);
  });

  test('404 when delete affects no rows', async () => {
    expectKybVerified(100, 'driver');
    dbMock.expectSelect(/FROM ratings\s+WHERE id = \?/i).returns([{ id: 1, rater_id: 100 }]);
    dbMock.expectDelete(/DELETE FROM ratings WHERE id = \?/i).returnsAffected(0);
    const res = await request(app())
      .delete('/api/ratings/1')
      .set(authHeader(tokenForDriver(100)));
    expect(res.status).toBe(404);
  });
});
