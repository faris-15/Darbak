const request = require('supertest');
const jwt = require('jsonwebtoken');
const { createTestApp } = require('./helpers/createTestApp');

jest.mock('../controllers/authController', () => ({
  register: jest.fn((req, res) => res.status(201).json({ success: true, id: 1 })),
  login: jest.fn((req, res) => res.status(200).json({ success: true, token: 't' })),
  getPendingUsers: jest.fn((req, res) => res.status(200).json({ success: true, data: [] })),
  setUserVerification: jest.fn((req, res) => res.status(200).json({ success: true })),
  updateProfile: jest.fn((req, res) => res.status(200).json({ message: 'ok' })),
  getProfile: jest.fn((req, res) => res.status(200).json({ id: Number(req.params.id) })),
  updateDeviceToken: jest.fn((req, res) => {
    if (!req.body.token || typeof req.body.token !== 'string') {
      return res.status(400).json({ message: 'invalid token' });
    }
    return res.status(200).json({ success: true });
  }),
}));

jest.mock('../utils/s3Config', () => ({
  upload: {
    single: jest.fn(() => (req, res, cb) => cb()),
  },
  logS3SdkErrorResponsePreview: jest.fn(async () => {}),
  sanitizeApiErrorMessage: jest.fn((m) => m),
}));

const authController = require('../controllers/authController');
const authRoutes = require('../routes/authRoutes');
const app = createTestApp('/api/auth', authRoutes);

const signToken = (payload = { id: 1, role: 'driver' }, expiresIn = '1h') =>
  jwt.sign(payload, process.env.JWT_SECRET, { expiresIn });

describe('Auth Routes - /api/auth/*', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('POST /api/auth/register', () => {
    const validBody = {
      fullName: 'Test User',
      email: 'user@example.com',
      phone: '0512345678',
      password: 'secret12',
      role: 'driver',
    };

    test('registers user with valid payload', async () => {
      const res = await request(app).post('/api/auth/register').send(validBody);
      expect(res.status).toBe(201);
      expect(authController.register).toHaveBeenCalledTimes(1);
    });

    test.each([
      ['missing fullName', { ...validBody, fullName: undefined }, 400],
      ['missing email', { ...validBody, email: undefined }, 400],
      ['missing phone', { ...validBody, phone: undefined }, 400],
      ['missing password', { ...validBody, password: undefined }, 400],
      ['missing all required fields', {}, 400],
      ['null email', { ...validBody, email: null }, 400],
      ['empty email', { ...validBody, email: '' }, 400],
      ['whitespace only fullName', { ...validBody, fullName: '   ' }, 201],
      ['weak password min-1 boundary', { ...validBody, password: '12345' }, 400],
      ['invalid email format no at sign', { ...validBody, email: 'testmail.com' }, 400],
      ['wrong role value', { ...validBody, role: 'superadmin' }, 400],
      ['sql injection email payload', { ...validBody, email: "' OR 1=1 --@x.com" }, 400],
      ['xss payload in fullName', { ...validBody, fullName: '<script>alert(1)</script>' }, 201],
      ['oversized fullName field', { ...validBody, fullName: 'a'.repeat(4000) }, 201],
    ])('returns expected status on %s', async (_, payload, expected) => {
      const res = await request(app).post('/api/auth/register').send(payload);
      expect(res.status).toBe(expected);
    });
  });

  describe('POST /api/auth/login', () => {
    const validLogin = { identifier: 'user@example.com', password: 'secret12' };

    test('logs in successfully with valid credentials', async () => {
      const res = await request(app).post('/api/auth/login').send(validLogin);
      expect(res.status).toBe(200);
      expect(authController.login).toHaveBeenCalledTimes(1);
    });

    test.each([
      ['missing identifier', { password: 'secret12' }, 400],
      ['missing password', { identifier: 'user@example.com' }, 400],
      ['missing all', {}, 400],
      ['identifier null', { identifier: null, password: 'secret12' }, 400],
      ['identifier empty', { identifier: '', password: 'secret12' }, 400],
      ['password empty', { identifier: 'u', password: '' }, 400],
      ['identifier whitespace only', { identifier: '   ', password: 'secret12' }, 200],
      ['password whitespace only', { identifier: 'user@example.com', password: '   ' }, 200],
      ['sql injection identifier', { identifier: "' OR 1=1 --", password: 'x' }, 200],
      ['xss identifier', { identifier: '<script>alert(1)</script>', password: 'x' }, 200],
      ['oversized identifier', { identifier: 'a'.repeat(5000), password: 'x' }, 200],
      ['wrong type for password', { identifier: 'user@example.com', password: 123456 }, 200],
    ])('returns expected status for validation scenario: %s', async (_, payload, expected) => {
      const res = await request(app).post('/api/auth/login').send(payload);
      expect(res.status).toBe(expected);
    });
  });

  describe('PUT /api/auth/profile/:id', () => {
    const validBody = { fullName: 'Name', email: 'u@example.com', phone: '0512345678' };

    test('updates profile with valid body', async () => {
      const res = await request(app).put('/api/auth/profile/10').send(validBody);
      expect(res.status).toBe(200);
      expect(authController.updateProfile).toHaveBeenCalledTimes(1);
    });

    test.each([
      ['missing fullName', { email: 'u@example.com', phone: '0512345678' }, 400],
      ['missing email', { fullName: 'Name', phone: '0512345678' }, 400],
      ['missing phone', { fullName: 'Name', email: 'u@example.com' }, 400],
      ['null fullName', { ...validBody, fullName: null }, 400],
      ['empty fullName', { ...validBody, fullName: '' }, 400],
      ['whitespace fullName', { ...validBody, fullName: '   ' }, 200],
      ['invalid email format', { ...validBody, email: 'bad-mail' }, 400],
      ['sql injection in phone', { ...validBody, phone: "' OR 1=1 --" }, 200],
      ['xss in fullName', { ...validBody, fullName: '<script>x</script>' }, 200],
      ['oversized name', { ...validBody, fullName: 'x'.repeat(2048) }, 200],
      ['wrong phone type', { ...validBody, phone: 12345 }, 200],
    ])('returns expected status on %s', async (_, payload, expected) => {
      const res = await request(app).put('/api/auth/profile/10').send(payload);
      expect(res.status).toBe(expected);
    });
  });

  describe('GET /api/auth/profile/:id', () => {
    test.each([
      ['valid numeric id', '1', 200],
      ['non-numeric id still routed', 'abc', 200],
      ['boundary zero id', '0', 200],
      ['negative id format', '-1', 200],
      ['long id value', '999999999999999', 200],
    ])('returns mocked profile result for %s', async (_, id, expected) => {
      const res = await request(app).get(`/api/auth/profile/${id}`);
      expect(res.status).toBe(expected);
    });
  });

  describe('POST /api/auth/device-token', () => {
    test('valid token and valid auth returns success', async () => {
      const token = signToken({ id: 5, role: 'driver' });
      const res = await request(app)
        .post('/api/auth/device-token')
        .set('Authorization', `Bearer ${token}`)
        .send({ token: 'fcm-token' });
      expect(res.status).toBe(200);
    });

    test('no auth token returns 401', async () => {
      const res = await request(app).post('/api/auth/device-token').send({ token: 'abc' });
      expect(res.status).toBe(401);
    });

    test('expired token returns 401', async () => {
      const token = signToken({ id: 2, role: 'driver' }, '-1s');
      const res = await request(app)
        .post('/api/auth/device-token')
        .set('Authorization', `Bearer ${token}`)
        .send({ token: 'abc' });
      expect(res.status).toBe(401);
    });

    test('malformed token returns 401', async () => {
      const res = await request(app)
        .post('/api/auth/device-token')
        .set('Authorization', 'Bearer malformed.token.value')
        .send({ token: 'abc' });
      expect(res.status).toBe(401);
    });

    test('wrong role token still authenticated route-wise', async () => {
      const token = signToken({ id: 9, role: 'shipper' });
      const res = await request(app)
        .post('/api/auth/device-token')
        .set('Authorization', `Bearer ${token}`)
        .send({ token: 'abc' });
      expect(res.status).toBe(200);
    });

    test.each([
      ['missing body token', {}, 400],
      ['null body token', { token: null }, 400],
      ['empty body token', { token: '' }, 400],
      ['whitespace body token', { token: '   ' }, 200],
      ['oversized body token', { token: 'x'.repeat(10000) }, 200],
      ['number type token', { token: 1234 }, 400],
      ['sql injection token', { token: "' OR 1=1 --" }, 200],
      ['xss token', { token: '<script>alert(1)</script>' }, 200],
    ])('returns expected status for input case: %s', async (_, payload, expected) => {
      const token = signToken({ id: 5, role: 'driver' });
      const res = await request(app)
        .post('/api/auth/device-token')
        .set('Authorization', `Bearer ${token}`)
        .send(payload);
      expect(res.status).toBe(expected);
    });
  });
});
