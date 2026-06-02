/**
 * Branch coverage for the authController paths that the main suite does not
 * exercise:
 *
 *   - register: full driver happy path with truck classification + truck
 *     INSERT, documentPath URL-parsing failure, Firebase Auth createUser
 *     throwing a non-"email-already-exists" error (best-effort swallow)
 *   - login: 500 catch when findByPhoneOrEmail throws
 *   - loginWithFirebase: invalid-id-token catch branch
 *   - getProfile: 200 happy-path
 *   - getProfile catch path remains in main suite
 *   - requestFirebasePasswordReset:
 *       * getUserByEmail throws a non-user-not-found error → 500
 *       * sendOobCode returns EMAIL_NOT_FOUND → 404
 *       * res.json() throws → caught fallback returns 502
 *       * unexpected exception → 500
 */
'use strict';

const bcrypt = require('bcryptjs');
const request = require('supertest');

const { buildTestApp } = require('../helpers/testApp');
const { dbMock } = require('../helpers/db');
const firebaseAdmin = require('../helpers/firebaseAdminMock');
const { userFactory } = require('../helpers/factories');
const { tokenForAdmin, authHeader } = require('../helpers/auth');

const app = () => buildTestApp({ routes: ['auth'] });
const PASSWORD = 'password123';
let HASHED;
beforeAll(async () => {
  HASHED = await bcrypt.hash(PASSWORD, 10);
});

describe('POST /api/auth/register — driver + Firebase edge cases', () => {
  test('201 driver happy path with valid truck classification', async () => {
    // Firebase admin's createUser succeeds (default factory mock).
    firebaseAdmin.__setApp({
      auth: () => ({ createUser: jest.fn(async () => ({ uid: 'fb-driver' })) }),
    });
    dbMock.expectSelect(/SELECT id FROM users WHERE phone/i).returns([]);
    dbMock.expectSelect(/SELECT id FROM users WHERE LOWER\(email\)/i).returns([]);
    dbMock.expectInsert(/INSERT INTO users/).returnsInsert(81);
    dbMock.expectInsert(/INSERT INTO wallets/).returnsInsert(1);
    dbMock.expectInsert(/INSERT INTO trucks/).returnsInsert(1);

    const res = await request(app())
      .post('/api/auth/register')
      .send({
        fullName: 'سائق جديد',
        email: 'd@x.com',
        phone: '0500123456',
        password: 'password123',
        role: 'driver',
        licenseNo: 'L-1',
        plateNumber: 'AAA-1234',
        isthimaraNo: 'I-1',
        category: 'medium_double_5_10',
        axle_count: 2,
        body_type: 'box',
        payload_capacity: '5_10',
        max_weight_tons: 7.5,
      });
    expect(res.status).toBe(201);
    expect(res.body.user.id).toBe(81);
  });

  test('201 documentPath that fails URL parsing falls back to the raw string', async () => {
    firebaseAdmin.__reset(); // Firebase admin missing → skipped silently.
    dbMock.expectSelect(/SELECT id FROM users WHERE phone/i).returns([]);
    dbMock.expectSelect(/SELECT id FROM users WHERE LOWER\(email\)/i).returns([]);
    dbMock.expectInsert(/INSERT INTO users/).returnsInsert(82);
    dbMock.expectInsert(/INSERT INTO wallets/).returnsInsert(1);
    dbMock.expectInsert(/INSERT INTO compliance_documents/i).returnsInsert(2);

    const res = await request(app())
      .post('/api/auth/register')
      .send({
        fullName: 'CR Holder',
        email: 'cr2@x.com',
        phone: '0500123457',
        password: 'password123',
        role: 'shipper',
        commercialNo: 'CR-2',
        // Includes 'http' substring (triggers URL parse path) but is NOT a
        // valid URL, forcing the catch fallback at line 150.
        documentPath: 'http-corrupted::/no-bucket/file.pdf',
      });
    expect(res.status).toBe(201);
  });

  test('201 register tolerates Firebase createUser throwing a generic error', async () => {
    firebaseAdmin.__setApp({
      auth: () => ({
        createUser: jest.fn(async () => {
          const e = new Error('quota');
          e.code = 'auth/internal-error';
          throw e;
        }),
      }),
    });
    dbMock.expectSelect(/SELECT id FROM users WHERE phone/i).returns([]);
    dbMock.expectSelect(/SELECT id FROM users WHERE LOWER\(email\)/i).returns([]);
    dbMock.expectInsert(/INSERT INTO users/).returnsInsert(83);
    dbMock.expectInsert(/INSERT INTO wallets/).returnsInsert(1);

    const res = await request(app())
      .post('/api/auth/register')
      .send({
        fullName: 'Tolerant',
        email: 'tol@x.com',
        phone: '0500123458',
        password: 'password123',
        role: 'shipper',
        commercialNo: 'CR-99',
      });
    expect(res.status).toBe(201);
  });
});

describe('POST /api/auth/login — catch branch', () => {
  test('500 when findByPhoneOrEmail throws', async () => {
    dbMock
      .expectSelect(/FROM users WHERE phone = \? OR email = \?/i)
      .rejectsWith(new Error('db down'));
    const res = await request(app())
      .post('/api/auth/login')
      .send({ identifier: '0501112222', password: PASSWORD });
    expect(res.status).toBe(500);
  });
});

describe('POST /api/auth/login-firebase — invalid token branch', () => {
  test('401 when verifyIdToken throws auth/invalid-id-token', async () => {
    firebaseAdmin.__setApp({
      auth: () => ({
        verifyIdToken: jest.fn(async () => {
          const e = new Error('bad');
          e.code = 'auth/invalid-id-token';
          throw e;
        }),
      }),
    });
    const res = await request(app())
      .post('/api/auth/login-firebase')
      .send({ idToken: 'bad-token' });
    expect(res.status).toBe(401);
    expect(res.body.message).toMatch(/غير صالح/);
  });

  test('500 when verifyIdToken throws an unknown error', async () => {
    firebaseAdmin.__setApp({
      auth: () => ({
        verifyIdToken: jest.fn(async () => {
          throw new Error('unexpected');
        }),
      }),
    });
    const res = await request(app())
      .post('/api/auth/login-firebase')
      .send({ idToken: 'tok' });
    expect(res.status).toBe(500);
  });

  test('403 when user is deactivated', async () => {
    firebaseAdmin.__setApp({
      auth: () => ({ verifyIdToken: jest.fn(async () => ({ email: 'u@x.com' })) }),
    });
    dbMock
      .expectSelect(/FROM users WHERE LOWER\(email\) = LOWER\(\?\) LIMIT 1/i)
      .returns([userFactory({ id: 11, email: 'u@x.com', is_active: 0 })]);
    const res = await request(app())
      .post('/api/auth/login-firebase')
      .send({ idToken: 'tok' });
    expect(res.status).toBe(403);
  });
});

describe('GET /api/auth/profile/:id — 200 happy path', () => {
  test('returns the built profile envelope for an existing shipper', async () => {
    dbMock
      .expectSelect(/SELECT \* FROM users WHERE id = \?/i)
      .returns([userFactory({ id: 200, role: 'shipper' })]);
    // Shipper-specific stats query
    dbMock
      .expectSelect(/FROM shipments WHERE shipper_id = \?/i)
      .returns([
        { total_shipments: 5, delivered_shipments: 2, active_shipments: 1 },
      ]);
    // Rating.getAverageRating
    dbMock
      .expectSelect(/FROM ratings WHERE rated_id/i)
      .returns([{ average_rating: 4.6, total_ratings: 12 }]);
    const res = await request(app())
      .get('/api/auth/profile/200')
      .set(authHeader(tokenForAdmin()));
    expect(res.status).toBe(200);
    expect(res.body.id).toBe(200);
  });
});

describe('POST /api/auth/password-reset-request — additional branches', () => {
  beforeEach(() => {
    process.env.FIREBASE_WEB_API_KEY = 'web-api-key';
  });

  test('500 when getUserByEmail throws a generic error', async () => {
    firebaseAdmin.__setApp({
      auth: () => ({
        getUserByEmail: jest.fn(async () => {
          throw new Error('unexpected firebase failure');
        }),
      }),
    });
    const res = await request(app())
      .post('/api/auth/password-reset-request')
      .send({ email: 'a@b.co' });
    expect(res.status).toBe(500);
  });

  test('404 when sendOobCode replies EMAIL_NOT_FOUND', async () => {
    firebaseAdmin.__setApp({
      auth: () => ({ getUserByEmail: jest.fn(async () => ({ uid: '1' })) }),
    });
    globalThis.fetch = jest.fn(async () => ({
      ok: false,
      status: 400,
      json: async () => ({ error: { message: 'EMAIL_NOT_FOUND' } }),
    }));
    const res = await request(app())
      .post('/api/auth/password-reset-request')
      .send({ email: 'gone@x.com' });
    expect(res.status).toBe(404);
  });

  test('502 when identitytoolkit response body cannot be parsed', async () => {
    firebaseAdmin.__setApp({
      auth: () => ({ getUserByEmail: jest.fn(async () => ({ uid: '1' })) }),
    });
    globalThis.fetch = jest.fn(async () => ({
      ok: false,
      status: 500,
      json: async () => {
        throw new Error('not json');
      },
    }));
    const res = await request(app())
      .post('/api/auth/password-reset-request')
      .send({ email: 'a@b.co' });
    expect(res.status).toBe(502);
  });
});
