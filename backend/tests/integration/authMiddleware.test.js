/**
 * Integration tests for middleware/authMiddleware.js
 *
 * The middleware decides who can call which endpoint, so we exercise it
 * against real Express routes (mounted via testApp) and a real
 * jsonwebtoken.verify(). This catches:
 *   - missing / malformed / expired tokens
 *   - bad signatures (wrong secret)
 *   - admin-only routes
 *   - KYB blocking for unverified driver/shipper, deactivated accounts,
 *     and rejected verification status (with specific Arabic messaging)
 *   - admin role bypassing KYB
 *
 * The tests sit in `integration/` because they exercise the full HTTP stack.
 */
'use strict';

const express = require('express');
const request = require('supertest');

const {
  requireAuth,
  requireAdmin,
  requireKybVerifiedIfDriverOrShipper,
} = require('../../middleware/authMiddleware');
const {
  tokenForDriver,
  tokenForShipper,
  tokenForAdmin,
  expiredToken,
  tokenWithBadSecret,
  authHeader,
} = require('../helpers/auth');
const { dbMock } = require('../helpers/db');
const { userFactory } = require('../helpers/factories');

const buildAuthApp = () => {
  const app = express();
  app.use(express.json());

  app.get('/auth/echo', requireAuth, (req, res) => res.json({ user: req.user }));

  app.get(
    '/auth/admin-only',
    requireAuth,
    requireAdmin,
    (_req, res) => res.json({ ok: true })
  );

  app.get(
    '/auth/kyb',
    requireAuth,
    requireKybVerifiedIfDriverOrShipper,
    (_req, res) => res.json({ ok: true })
  );

  return app;
};

describe('requireAuth', () => {
  const app = buildAuthApp();

  test('401 when Authorization header is missing', async () => {
    const res = await request(app).get('/auth/echo');
    expect(res.status).toBe(401);
    expect(res.body).toEqual({ message: 'Unauthorized' });
  });

  test('401 when header does not start with Bearer', async () => {
    const res = await request(app)
      .get('/auth/echo')
      .set({ Authorization: tokenForDriver() });
    expect(res.status).toBe(401);
  });

  test('401 for an expired token', async () => {
    const res = await request(app).get('/auth/echo').set(authHeader(expiredToken()));
    expect(res.status).toBe(401);
  });

  test('401 for a token signed with the wrong secret', async () => {
    const res = await request(app)
      .get('/auth/echo')
      .set(authHeader(tokenWithBadSecret()));
    expect(res.status).toBe(401);
  });

  test('401 when token is malformed', async () => {
    const res = await request(app)
      .get('/auth/echo')
      .set({ Authorization: 'Bearer not-a-jwt' });
    expect(res.status).toBe(401);
  });

  test('attaches req.user to next handler when token is valid', async () => {
    const res = await request(app).get('/auth/echo').set(authHeader(tokenForDriver(42)));
    expect(res.status).toBe(200);
    expect(res.body.user).toMatchObject({ id: 42, role: 'driver' });
  });
});

describe('requireAdmin', () => {
  const app = buildAuthApp();

  test('403 for non-admin', async () => {
    const res = await request(app)
      .get('/auth/admin-only')
      .set(authHeader(tokenForDriver()));
    expect(res.status).toBe(403);
    expect(res.body).toEqual({ message: 'Forbidden' });
  });

  test('200 for admin', async () => {
    const res = await request(app)
      .get('/auth/admin-only')
      .set(authHeader(tokenForAdmin()));
    expect(res.status).toBe(200);
  });

  test('403 if requireAuth populates req.user as null', async () => {
    // Build a tiny app that fakes a null user (defensive coverage of the
    // `!req.user` branch in requireAdmin).
    const app2 = express();
    app2.get('/x', (req, _res, next) => { req.user = null; next(); }, requireAdmin, (_req, res) => res.json({}));
    const res = await request(app2).get('/x');
    expect(res.status).toBe(403);
  });
});

describe('requireKybVerifiedIfDriverOrShipper', () => {
  const app = buildAuthApp();

  test('admins bypass the verification check (no DB call)', async () => {
    const res = await request(app)
      .get('/auth/kyb')
      .set(authHeader(tokenForAdmin()));
    expect(res.status).toBe(200);
    dbMock.assertAllConsumed();
  });

  test('passes when driver is verified', async () => {
    dbMock.expectSelect(/FROM users WHERE id = \?/i)
      .returns([userFactory({ id: 100, role: 'driver', verification_status: 'verified' })]);
    const res = await request(app)
      .get('/auth/kyb')
      .set(authHeader(tokenForDriver(100)));
    expect(res.status).toBe(200);
  });

  test('returns 403 KYB_NOT_VERIFIED when driver is pending', async () => {
    dbMock.expectSelect(/FROM users WHERE id = \?/i)
      .returns([userFactory({ id: 100, role: 'driver', verification_status: 'pending' })]);
    const res = await request(app)
      .get('/auth/kyb')
      .set(authHeader(tokenForDriver(100)));
    expect(res.status).toBe(403);
    expect(res.body).toMatchObject({
      success: false,
      code: 'KYB_NOT_VERIFIED',
      verification_status: 'pending',
    });
    expect(res.body.message).toMatch(/قيد مراجعة/);
  });

  test('returns rejected message specific to drivers', async () => {
    dbMock.expectSelect(/FROM users WHERE id = \?/i)
      .returns([userFactory({ id: 100, role: 'driver', verification_status: 'rejected' })]);
    const res = await request(app)
      .get('/auth/kyb')
      .set(authHeader(tokenForDriver(100)));
    expect(res.status).toBe(403);
    expect(res.body.message).toMatch(/لم تُقبل وثائقك/);
  });

  test('returns rejected message specific to shippers', async () => {
    dbMock.expectSelect(/FROM users WHERE id = \?/i)
      .returns([userFactory({ id: 200, role: 'shipper', verification_status: 'rejected' })]);
    const res = await request(app)
      .get('/auth/kyb')
      .set(authHeader(tokenForShipper(200)));
    expect(res.status).toBe(403);
    expect(res.body.message).toMatch(/شركتك/);
  });

  test('returns 403 with disabled message when is_active=0', async () => {
    dbMock.expectSelect(/FROM users WHERE id = \?/i)
      .returns([userFactory({ id: 100, role: 'driver', is_active: 0 })]);
    const res = await request(app)
      .get('/auth/kyb')
      .set(authHeader(tokenForDriver(100)));
    expect(res.status).toBe(403);
    expect(res.body.message).toMatch(/تم تعطيل/);
  });

  test('returns 401 when the user record vanished', async () => {
    dbMock.expectSelect(/FROM users WHERE id = \?/i).returns([]);
    const res = await request(app)
      .get('/auth/kyb')
      .set(authHeader(tokenForDriver(100)));
    expect(res.status).toBe(401);
  });

  test('returns 500 when DB blows up', async () => {
    dbMock.expectSelect(/FROM users WHERE id = \?/i)
      .rejectsWith(new Error('connection lost'));
    const res = await request(app)
      .get('/auth/kyb')
      .set(authHeader(tokenForDriver(100)));
    expect(res.status).toBe(500);
  });
});
