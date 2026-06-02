/**
 * Extra branch coverage for ratingController error/catch paths that the
 * happy-path suite does not exercise:
 *   - addRating catch (Notification swallowed; outer 500)
 *   - getUserRatings rated_profile catch branch
 *   - updateRating / deleteRating 500 catch paths
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

const app = () => buildTestApp({ routes: ['ratings'] });

const expectKybVerified = (id, role = 'driver') =>
  dbMock
    .expectSelect(/FROM users WHERE id = \?/i)
    .returns([userFactory({ id, role, verification_status: 'verified' })]);

describe('POST /api/ratings — addRating soft-failure branches', () => {
  test('201 even when Notification.create throws (best-effort)', async () => {
    expectKybVerified(100, 'driver');
    dbMock
      .expectSelect(/FROM shipments s\s+LEFT JOIN users sh/i)
      .returns([
        shipmentFactory({
          id: 1000,
          status: 'delivered',
          shipper_id: 200,
          driver_id: 100,
        }),
      ]);
    dbMock
      .expectSelect(/FROM ratings WHERE shipment_id = \? AND rater_id = \?/i)
      .returns([]);
    dbMock.expectInsert(/INSERT INTO ratings/i).returnsInsert(1);
    dbMock
      .expectSelect(/FROM ratings WHERE rated_id/i)
      .returns([{ average_rating: 4.7, total_ratings: 5 }]);

    const Notification = require('../../models/Notification');
    Notification.create.mockImplementationOnce(async () => {
      throw new Error('notif boom');
    });

    const res = await request(app())
      .post('/api/ratings')
      .set(authHeader(tokenForDriver(100)))
      .send({ shipment_id: 1000, rated_id: 200, stars: 5, comment: 'x' });
    expect(res.status).toBe(201);
  });

  test('500 when getAverageRating throws (outer catch)', async () => {
    expectKybVerified(100, 'driver');
    dbMock
      .expectSelect(/FROM shipments s\s+LEFT JOIN users sh/i)
      .returns([
        shipmentFactory({
          id: 1000,
          status: 'delivered',
          shipper_id: 200,
          driver_id: 100,
        }),
      ]);
    dbMock
      .expectSelect(/FROM ratings WHERE shipment_id = \? AND rater_id = \?/i)
      .returns([]);
    dbMock.expectInsert(/INSERT INTO ratings/i).returnsInsert(1);
    dbMock
      .expectSelect(/FROM ratings WHERE rated_id/i)
      .rejectsWith(new Error('db down'));

    const res = await request(app())
      .post('/api/ratings')
      .set(authHeader(tokenForDriver(100)))
      .send({ shipment_id: 1000, rated_id: 200, stars: 5 });
    expect(res.status).toBe(500);
  });
});

describe('GET /api/ratings/user/:userId — branches', () => {
  test('falls back to null rated_profile when buildReviewTargetPublicProfile throws', async () => {
    dbMock
      .expectSelect(/FROM users WHERE id = \?/i)
      .returns([userFactory({ id: 100, role: 'driver' })]);
    dbMock.expectSelect(/FROM ratings\s+WHERE rated_id = \?/i).returns([]);
    dbMock
      .expectSelect(/AVG\(CASE WHEN stars BETWEEN/i)
      .returns([{ average_rating: 0, total_ratings: 0 }]);
    // buildReviewTargetPublicProfile calls User.findById internally — make it
    // throw to exercise the catch branch.
    dbMock
      .expectSelect(/FROM users WHERE id = \?/i)
      .rejectsWith(new Error('boom'));

    const res = await request(app()).get('/api/ratings/user/100');
    expect(res.status).toBe(200);
    expect(res.body.rated_profile).toBeNull();
  });

  test('500 when initial users lookup throws', async () => {
    dbMock
      .expectSelect(/FROM users WHERE id = \?/i)
      .rejectsWith(new Error('db down'));
    const res = await request(app()).get('/api/ratings/user/100');
    expect(res.status).toBe(500);
  });
});

describe('PUT /api/ratings/:ratingId — updateRating 500', () => {
  test('500 when Rating.findById throws', async () => {
    expectKybVerified(100, 'driver');
    dbMock
      .expectSelect(/FROM ratings WHERE id = \?/i)
      .rejectsWith(new Error('db'));
    const res = await request(app())
      .put('/api/ratings/55')
      .set(authHeader(tokenForDriver(100)))
      .send({ stars: 4 });
    expect(res.status).toBe(500);
  });
});

describe('DELETE /api/ratings/:ratingId — deleteRating 500', () => {
  test('500 when Rating.findById throws', async () => {
    expectKybVerified(100, 'driver');
    dbMock
      .expectSelect(/FROM ratings WHERE id = \?/i)
      .rejectsWith(new Error('db'));
    const res = await request(app())
      .delete('/api/ratings/55')
      .set(authHeader(tokenForDriver(100)));
    expect(res.status).toBe(500);
  });
});
