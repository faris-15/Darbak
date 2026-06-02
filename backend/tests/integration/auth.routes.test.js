/**
 * Integration tests for /api/auth/* (controllers/authController.js +
 * routes/authRoutes.js).
 *
 * These tests run the real Express stack — express-validator, the controllers,
 * the JWT signing — but the database, S3, Firebase Admin, and FCM are mocked
 * (see tests/setup.js). That gives us:
 *
 *   - production-fidelity request shape (headers, JSON body, status codes)
 *   - per-test SQL assertions via dbMock
 *   - sub-second test runs
 *
 * Coverage scope:
 *   - POST /api/auth/register — express-validator gating + happy path with
 *     transactions + duplicate phone/email + driver-specific truck rules
 *   - POST /api/auth/login — wrong password, deactivated account, success
 *   - POST /api/auth/login-firebase — id token verification, password sync
 *   - POST /api/auth/password-reset-request — email validation, throttling,
 *     Firebase service unavailable, sendOobCode failures, success
 *   - PUT /api/auth/profile/:id — owner vs admin authorization
 *   - POST /api/auth/device-token — auth required + body validation
 */
'use strict';

const bcrypt = require('bcryptjs');
const request = require('supertest');

const { buildTestApp } = require('../helpers/testApp');
const { dbMock } = require('../helpers/db');
const firebaseAdmin = require('../helpers/firebaseAdminMock');
const { userFactory } = require('../helpers/factories');
const {
  tokenForDriver,
  tokenForShipper,
  tokenForAdmin,
  authHeader,
} = require('../helpers/auth');

const PASSWORD = 'password123';
let HASHED;
beforeAll(async () => {
  HASHED = await bcrypt.hash(PASSWORD, 10);
});

const app = () => buildTestApp({ routes: ['auth'] });

// -------------------------- POST /api/auth/register --------------------------

describe('POST /api/auth/register', () => {
  test('400 when express-validator finds missing fields', async () => {
    const res = await request(app()).post('/api/auth/register').send({});
    expect(res.status).toBe(400);
    expect(res.body.errors).toBeDefined();
  });

  test('400 when role=driver and license/plate/isthimara missing', async () => {
    const res = await request(app())
      .post('/api/auth/register')
      .send({
        fullName: 'Hassan',
        email: 'h@x.com',
        phone: '0501234567',
        password: 'password123',
        role: 'driver',
      });
    expect(res.status).toBe(400);
    expect(res.body.message).toMatch(/بيانات السائق/);
  });

  test('400 when role=driver and truck classification invalid', async () => {
    const res = await request(app())
      .post('/api/auth/register')
      .send({
        fullName: 'Hassan',
        email: 'h@x.com',
        phone: '0501234567',
        password: 'password123',
        role: 'driver',
        licenseNo: 'L1',
        plateNumber: 'AAA-1',
        isthimaraNo: 'I1',
        category: 'imaginary_category',
      });
    expect(res.status).toBe(400);
    expect(res.body.message).toMatch(/فئة الشاحنة/);
  });

  test('400 when phone or email already in use', async () => {
    dbMock.expectSelect(/SELECT id FROM users WHERE phone = \?/i).returns([{ id: 9 }]);
    dbMock.expectSelect(/SELECT id FROM users WHERE LOWER\(email\) = LOWER\(\?\)/i).returns([]);
    const res = await request(app())
      .post('/api/auth/register')
      .send({
        fullName: 'Hassan',
        email: 'h@x.com',
        phone: '0501234567',
        password: 'password123',
        role: 'shipper',
        commercialNo: 'CR-9999',
      });
    expect(res.status).toBe(400);
    expect(res.body.message).toMatch(/مستخدم مسبقاً/);
  });

  test('201 happy path for a shipper registers + creates wallet + issues JWT', async () => {
    dbMock.expectSelect(/SELECT id FROM users WHERE phone/i).returns([]);
    dbMock.expectSelect(/SELECT id FROM users WHERE LOWER\(email\)/i).returns([]);
    dbMock.expectInsert(/INSERT INTO users/).returnsInsert(7);
    dbMock.expectInsert(/INSERT INTO wallets/).returnsInsert(1);

    const res = await request(app())
      .post('/api/auth/register')
      .send({
        fullName: 'Hassan',
        email: 'H@x.COM',
        phone: '0501234567',
        password: 'password123',
        role: 'shipper',
        commercialNo: 'CR-9999',
      });

    expect(res.status).toBe(201);
    expect(res.body).toMatchObject({
      success: true,
      user: { id: 7, role: 'shipper', verification_status: 'pending' },
    });
    expect(typeof res.body.token).toBe('string');
    expect(dbMock.transactionEvents).toEqual(['begin', 'commit', 'release']);
  });

  test('rolls back the transaction on insert failure', async () => {
    dbMock.expectSelect(/SELECT id FROM users WHERE phone/i).returns([]);
    dbMock.expectSelect(/SELECT id FROM users WHERE LOWER\(email\)/i).returns([]);
    dbMock.expectInsert(/INSERT INTO users/).rejectsWith(new Error('boom'));

    const res = await request(app())
      .post('/api/auth/register')
      .send({
        fullName: 'Hassan',
        email: 'h@x.com',
        phone: '0501234567',
        password: 'password123',
        role: 'shipper',
      });
    expect(res.status).toBe(500);
    expect(dbMock.transactionEvents).toContain('rollback');
    expect(dbMock.transactionEvents).toContain('release');
  });
});

// ---------------------------- POST /api/auth/login ---------------------------

describe('POST /api/auth/login', () => {
  test('400 when identifier or password missing', async () => {
    const res = await request(app()).post('/api/auth/login').send({});
    expect(res.status).toBe(400);
  });

  test('401 when user not found', async () => {
    dbMock.expectSelect(/FROM users WHERE phone = \? OR email = \?/i).returns([]);
    const res = await request(app())
      .post('/api/auth/login')
      .send({ identifier: '0501234567', password: 'pw' });
    expect(res.status).toBe(401);
    expect(res.body.message).toMatch(/بيانات الدخول غير صحيحة/);
  });

  test('401 when password mismatches', async () => {
    dbMock.expectSelect(/FROM users WHERE phone = \? OR email = \?/i)
      .returns([userFactory({ password: HASHED })]);
    const res = await request(app())
      .post('/api/auth/login')
      .send({ identifier: '0501234567', password: 'wrong-password' });
    expect(res.status).toBe(401);
  });

  test('403 when account is deactivated', async () => {
    dbMock.expectSelect(/FROM users WHERE phone = \? OR email = \?/i)
      .returns([userFactory({ password: HASHED, is_active: 0 })]);
    const res = await request(app())
      .post('/api/auth/login')
      .send({ identifier: '0501234567', password: PASSWORD });
    expect(res.status).toBe(403);
    expect(res.body.message).toMatch(/تم تعطيل/);
  });

  test('200 with token + presigned profile image when user has one', async () => {
    dbMock.expectSelect(/FROM users WHERE phone = \? OR email = \?/i)
      .returns([userFactory({ password: HASHED, profile_image_url: 'profile/abc.jpg' })]);
    const res = await request(app())
      .post('/api/auth/login')
      .send({ identifier: '0501234567', password: PASSWORD });
    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(typeof res.body.token).toBe('string');
    expect(res.body.user.profile_image_url).toMatch(/test-s3.local/);
  });
});

// --------------------- POST /api/auth/login-firebase --------------------

describe('POST /api/auth/login-firebase', () => {
  test('400 when idToken missing', async () => {
    const res = await request(app()).post('/api/auth/login-firebase').send({});
    expect(res.status).toBe(400);
  });

  test('503 when Firebase Admin is not configured', async () => {
    firebaseAdmin.__reset();
    const res = await request(app())
      .post('/api/auth/login-firebase')
      .send({ idToken: 'tok' });
    expect(res.status).toBe(503);
  });

  test('401 when verifyIdToken throws id-token-expired', async () => {
    firebaseAdmin.__setApp({
      auth: () => ({
        verifyIdToken: jest.fn(async () => {
          const err = new Error('expired');
          err.code = 'auth/id-token-expired';
          throw err;
        }),
      }),
    });
    const res = await request(app())
      .post('/api/auth/login-firebase')
      .send({ idToken: 'tok' });
    expect(res.status).toBe(401);
    expect(res.body.message).toMatch(/انتهت صلاحية/);
  });

  test('400 when token has no email claim', async () => {
    firebaseAdmin.__setApp({
      auth: () => ({ verifyIdToken: jest.fn(async () => ({ email: '' })) }),
    });
    const res = await request(app())
      .post('/api/auth/login-firebase')
      .send({ idToken: 'tok' });
    expect(res.status).toBe(400);
  });

  test('404 when no MySQL user matches the email', async () => {
    firebaseAdmin.__setApp({
      auth: () => ({ verifyIdToken: jest.fn(async () => ({ email: 'u@x.com' })) }),
    });
    dbMock.expectSelect(/FROM users WHERE LOWER\(email\) = LOWER\(\?\) LIMIT 1/i).returns([]);
    const res = await request(app())
      .post('/api/auth/login-firebase')
      .send({ idToken: 'tok' });
    expect(res.status).toBe(404);
  });

  test('200 issues JWT and rotates password when one is provided', async () => {
    firebaseAdmin.__setApp({
      auth: () => ({ verifyIdToken: jest.fn(async () => ({ email: 'u@x.com' })) }),
    });
    dbMock
      .expectSelect(/FROM users WHERE LOWER\(email\) = LOWER\(\?\) LIMIT 1/i)
      .returns([userFactory({ id: 11, email: 'u@x.com' })]);
    dbMock.expectUpdate(/UPDATE users SET password = \? WHERE id = \?/i).returnsAffected(1);

    const res = await request(app())
      .post('/api/auth/login-firebase')
      .send({ idToken: 'tok', password: 'newPass1' });
    expect(res.status).toBe(200);
    expect(res.body.token).toBeDefined();
  });

  test('400 when supplied password fails complexity policy', async () => {
    firebaseAdmin.__setApp({
      auth: () => ({ verifyIdToken: jest.fn(async () => ({ email: 'u@x.com' })) }),
    });
    dbMock
      .expectSelect(/FROM users WHERE LOWER\(email\) = LOWER\(\?\) LIMIT 1/i)
      .returns([userFactory({ id: 11, email: 'u@x.com' })]);

    const res = await request(app())
      .post('/api/auth/login-firebase')
      .send({ idToken: 'tok', password: 'allletters' }); // missing digit
    expect(res.status).toBe(400);
    expect(res.body.message).toMatch(/كلمة المرور/);
  });
});

// --------------- POST /api/auth/password-reset-request ----------------

describe('POST /api/auth/password-reset-request', () => {
  test('400 for invalid email', async () => {
    const res = await request(app())
      .post('/api/auth/password-reset-request')
      .send({ email: 'bad' });
    expect(res.status).toBe(400);
  });

  test('503 when Firebase admin is missing', async () => {
    firebaseAdmin.__reset();
    const res = await request(app())
      .post('/api/auth/password-reset-request')
      .send({ email: 'a@b.co' });
    expect(res.status).toBe(503);
  });

  test('404 when Firebase reports user-not-found', async () => {
    firebaseAdmin.__setApp({
      auth: () => ({
        getUserByEmail: jest.fn(async () => {
          const err = new Error('not found');
          err.code = 'auth/user-not-found';
          throw err;
        }),
      }),
    });
    const res = await request(app())
      .post('/api/auth/password-reset-request')
      .send({ email: 'a@b.co' });
    expect(res.status).toBe(404);
  });

  test('503 when FIREBASE_WEB_API_KEY is missing', async () => {
    delete process.env.FIREBASE_WEB_API_KEY;
    firebaseAdmin.__setApp({
      auth: () => ({ getUserByEmail: jest.fn(async () => ({ uid: '1' })) }),
    });
    const res = await request(app())
      .post('/api/auth/password-reset-request')
      .send({ email: 'a@b.co' });
    expect(res.status).toBe(503);
  });

  test('200 happy path forwards to identitytoolkit', async () => {
    process.env.FIREBASE_WEB_API_KEY = 'web-api-key';
    firebaseAdmin.__setApp({
      auth: () => ({ getUserByEmail: jest.fn(async () => ({ uid: '1' })) }),
    });
    globalThis.fetch = jest.fn(async () => ({
      ok: true,
      json: async () => ({ email: 'a@b.co' }),
    }));

    const res = await request(app())
      .post('/api/auth/password-reset-request')
      .send({ email: 'A@B.co' });
    expect(res.status).toBe(200);
    expect(globalThis.fetch).toHaveBeenCalledWith(
      expect.stringContaining('accounts:sendOobCode?key=web-api-key'),
      expect.objectContaining({ method: 'POST' })
    );
  });

  test('502 when identitytoolkit returns generic failure', async () => {
    process.env.FIREBASE_WEB_API_KEY = 'web-api-key';
    firebaseAdmin.__setApp({
      auth: () => ({ getUserByEmail: jest.fn(async () => ({ uid: '1' })) }),
    });
    globalThis.fetch = jest.fn(async () => ({
      ok: false,
      json: async () => ({ error: { message: 'INTERNAL' } }),
      status: 500,
    }));

    const res = await request(app())
      .post('/api/auth/password-reset-request')
      .send({ email: 'a@b.co' });
    expect(res.status).toBe(502);
  });

  test('429 when same IP exceeds the per-hour throttle', async () => {
    process.env.FIREBASE_WEB_API_KEY = 'web-api-key';
    firebaseAdmin.__setApp({
      auth: () => ({ getUserByEmail: jest.fn(async () => ({ uid: '1' })) }),
    });
    globalThis.fetch = jest.fn(async () => ({ ok: true, json: async () => ({}) }));

    const a = app();
    // 25 successful calls, the 26th must be 429
    for (let i = 0; i < 25; i += 1) {
      await request(a)
        .post('/api/auth/password-reset-request')
        .send({ email: `u${i}@x.co` });
    }
    const res = await request(a)
      .post('/api/auth/password-reset-request')
      .send({ email: 'u@x.co' });
    expect(res.status).toBe(429);
  });
});

// ----------------------- PUT /api/auth/profile/:id ---------------------

describe('PUT /api/auth/profile/:id', () => {
  test('401 without a token', async () => {
    const res = await request(app())
      .put('/api/auth/profile/200')
      .send({ fullName: 'X', email: 'x@y.com', phone: '0501231234' });
    expect(res.status).toBe(401);
  });

  test('403 when caller tries to edit another user (and is not admin)', async () => {
    const res = await request(app())
      .put('/api/auth/profile/200')
      .set(authHeader(tokenForDriver(100)))
      .send({ fullName: 'X', email: 'x@y.com', phone: '0501231234' });
    expect(res.status).toBe(403);
  });

  test('200 admin can update any profile', async () => {
    dbMock.expectUpdate(/UPDATE users SET full_name/i).returnsAffected(1);
    const res = await request(app())
      .put('/api/auth/profile/200')
      .set(authHeader(tokenForAdmin()))
      .send({ fullName: 'X', email: 'x@y.com', phone: '0501231234' });
    expect(res.status).toBe(200);
  });

  test('200 user can update their own profile', async () => {
    dbMock.expectUpdate(/UPDATE users SET full_name/i).returnsAffected(1);
    const res = await request(app())
      .put('/api/auth/profile/200')
      .set(authHeader(tokenForShipper(200)))
      .send({ fullName: 'X', email: 'x@y.com', phone: '0501231234' });
    expect(res.status).toBe(200);
  });
});

// -------------- Admin-only auth routes (verification CRUD) -------------

describe('GET /api/auth/admin/pending-users', () => {
  test('200 lists pending users', async () => {
    dbMock
      .expectSelect(/WHERE verification_status = \?/i)
      .returns([{ id: 1 }, { id: 2 }]);
    const res = await request(app())
      .get('/api/auth/admin/pending-users')
      .set(authHeader(tokenForAdmin()));
    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.data).toHaveLength(2);
  });

  test('500 when DB throws', async () => {
    dbMock
      .expectSelect(/WHERE verification_status = \?/i)
      .rejectsWith(new Error('db-down'));
    const res = await request(app())
      .get('/api/auth/admin/pending-users')
      .set(authHeader(tokenForAdmin()));
    expect(res.status).toBe(500);
  });
});

describe('POST /api/auth/admin/users/:id/verify', () => {
  test('200 updates verification status', async () => {
    dbMock
      .expectUpdate(/UPDATE users SET verification_status = \?/i)
      .returnsAffected(1);
    const res = await request(app())
      .post('/api/auth/admin/users/9/verify')
      .set(authHeader(tokenForAdmin()))
      .send({ status: 'verified' });
    expect(res.status).toBe(200);
  });

  test('500 when update fails', async () => {
    dbMock
      .expectUpdate(/UPDATE users SET verification_status = \?/i)
      .rejectsWith(new Error('boom'));
    const res = await request(app())
      .post('/api/auth/admin/users/9/verify')
      .set(authHeader(tokenForAdmin()))
      .send({ status: 'verified' });
    expect(res.status).toBe(500);
  });
});

describe('GET /api/auth/profile/:id', () => {
  test('404 when user not found', async () => {
    dbMock
      .expectSelect(/SELECT \* FROM users WHERE id = \?/i)
      .returns([]);
    const res = await request(app())
      .get('/api/auth/profile/42')
      .set(authHeader(tokenForAdmin()));
    expect(res.status).toBe(404);
  });

  test('500 on internal error', async () => {
    dbMock
      .expectSelect(/SELECT \* FROM users WHERE id = \?/i)
      .rejectsWith(new Error('boom'));
    const res = await request(app())
      .get('/api/auth/profile/42')
      .set(authHeader(tokenForAdmin()));
    expect(res.status).toBe(500);
  });
});

describe('PUT /api/auth/profile/:id error path', () => {
  test('500 when update throws', async () => {
    dbMock
      .expectUpdate(/UPDATE users SET full_name = \?/i)
      .rejectsWith(new Error('boom'));
    const res = await request(app())
      .put('/api/auth/profile/200')
      .set(authHeader(tokenForShipper(200)))
      .send({ fullName: 'X', email: 'x@y.com', phone: '0501231234' });
    expect(res.status).toBe(500);
  });
});

// -------------------- POST /api/auth/device-token ---------------------

describe('POST /api/auth/device-token', () => {
  test('401 without token', async () => {
    const res = await request(app()).post('/api/auth/device-token').send({ token: 'x' });
    expect(res.status).toBe(401);
  });

  test('400 when token missing', async () => {
    const res = await request(app())
      .post('/api/auth/device-token')
      .set(authHeader(tokenForDriver()))
      .send({});
    expect(res.status).toBe(400);
  });

  test('200 stores fcm_token', async () => {
    dbMock.expectUpdate(/UPDATE users SET fcm_token = \? WHERE id = \?/i)
      .withParams(['device-abc', 100])
      .returnsAffected(1);
    const res = await request(app())
      .post('/api/auth/device-token')
      .set(authHeader(tokenForDriver(100)))
      .send({ token: 'device-abc' });
    expect(res.status).toBe(200);
  });

  test('500 when DB update throws', async () => {
    dbMock
      .expectUpdate(/UPDATE users SET fcm_token = \?/i)
      .rejectsWith(new Error('migration missing'));
    const res = await request(app())
      .post('/api/auth/device-token')
      .set(authHeader(tokenForDriver(100)))
      .send({ token: 'device-abc' });
    expect(res.status).toBe(500);
  });
});

// ----- Extra register branches: Firebase admin present + documentPath -----

describe('POST /api/auth/register (firebase + docs)', () => {
  test('201 creates Firebase user, stores compliance doc, and emits dashboard event', async () => {
    firebaseAdmin.__setApp({
      auth: () => ({
        createUser: jest.fn(async () => ({ uid: 'firebase-uid' })),
      }),
    });
    dbMock.expectSelect(/SELECT id FROM users WHERE phone/i).returns([]);
    dbMock.expectSelect(/SELECT id FROM users WHERE LOWER\(email\)/i).returns([]);
    dbMock.expectInsert(/INSERT INTO users/).returnsInsert(33);
    dbMock.expectInsert(/INSERT INTO wallets/).returnsInsert(1);
    dbMock.expectInsert(/INSERT INTO compliance_documents/i).returnsInsert(7);

    const res = await request(app())
      .post('/api/auth/register')
      .send({
        fullName: 'CR Holder',
        email: 'cr@x.com',
        phone: '0501112222',
        password: 'password123',
        role: 'shipper',
        commercialNo: 'CR-1',
        documentPath: 'http://minio:9000/darbak/commercial_docs/cr.pdf',
      });
    expect(res.status).toBe(201);
    expect(res.body.user.id).toBe(33);
  });

  test('201 register tolerates Firebase admin createUser error (auth/email-already-exists)', async () => {
    firebaseAdmin.__setApp({
      auth: () => ({
        createUser: jest.fn(async () => {
          const e = new Error('exists');
          e.code = 'auth/email-already-exists';
          throw e;
        }),
      }),
    });
    dbMock.expectSelect(/SELECT id FROM users WHERE phone/i).returns([]);
    dbMock.expectSelect(/SELECT id FROM users WHERE LOWER\(email\)/i).returns([]);
    dbMock.expectInsert(/INSERT INTO users/).returnsInsert(34);
    dbMock.expectInsert(/INSERT INTO wallets/).returnsInsert(1);

    const res = await request(app())
      .post('/api/auth/register')
      .send({
        fullName: 'Already',
        email: 'already@x.com',
        phone: '0509991112',
        password: 'password123',
        role: 'shipper',
        commercialNo: 'CR-2',
      });
    expect(res.status).toBe(201);
  });
});

// --- loginWithFirebase: extra branch (auth/argument-error -> 401) ---

describe('POST /api/auth/login-firebase extra branches', () => {
  test('401 when verifyIdToken throws auth/argument-error', async () => {
    firebaseAdmin.__setApp({
      auth: () => ({
        verifyIdToken: jest.fn(async () => {
          const err = new Error('bad');
          err.code = 'auth/argument-error';
          throw err;
        }),
      }),
    });
    const res = await request(app())
      .post('/api/auth/login-firebase')
      .send({ idToken: 'tok' });
    expect(res.status).toBe(401);
    expect(res.body.message).toMatch(/غير صالح/);
  });

  test('500 on unknown firebase error', async () => {
    firebaseAdmin.__setApp({
      auth: () => ({
        verifyIdToken: jest.fn(async () => {
          throw new Error('unknown');
        }),
      }),
    });
    const res = await request(app())
      .post('/api/auth/login-firebase')
      .send({ idToken: 'tok' });
    expect(res.status).toBe(500);
  });

  test('403 when matched user is deactivated', async () => {
    firebaseAdmin.__setApp({
      auth: () => ({ verifyIdToken: jest.fn(async () => ({ email: 'u@x.com' })) }),
    });
    dbMock
      .expectSelect(/FROM users WHERE LOWER\(email\) = LOWER\(\?\) LIMIT 1/i)
      .returns([userFactory({ id: 1, email: 'u@x.com', is_active: 0 })]);
    const res = await request(app())
      .post('/api/auth/login-firebase')
      .send({ idToken: 'tok' });
    expect(res.status).toBe(403);
  });
});

