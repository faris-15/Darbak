const request = require('supertest');
const jwt = require('jsonwebtoken');
const { createTestApp } = require('./helpers/createTestApp');

jest.mock('../controllers/shipmentController', () => ({
  createShipment: jest.fn((req, res) => res.status(201).json({ id: 1, shipper_id: req.user?.id })),
  listShipments: jest.fn((req, res) => res.status(200).json([])),
  getShipment: jest.fn((req, res) => {
    if (req.params.id === '404') return res.status(404).json({ message: 'not found' });
    return res.status(200).json({ id: Number(req.params.id) || req.params.id });
  }),
  getShipmentContractPdfUrl: jest.fn((req, res) => res.status(200).json({ url: 'https://signed-url' })),
  recordLiveLocation: jest.fn((req, res) => res.status(200).json({ message: 'ok' })),
  completeDelivery: jest.fn((req, res) => res.status(200).json({ success: true })),
  getActiveShipmentsForDriver: jest.fn((req, res) => res.status(200).json([])),
  getShipmentsForDriver: jest.fn((req, res) => res.status(200).json([])),
  updateShipmentStatus: jest.fn((req, res) => res.status(200).json({ status: req.body.status || 'updated' })),
}));

jest.mock('../utils/s3Config', () => ({
  upload: { single: jest.fn(() => (req, res, cb) => cb()) },
  logS3SdkErrorResponsePreview: jest.fn(async () => {}),
  sanitizeApiErrorMessage: jest.fn((m) => m),
}));

const shipmentController = require('../controllers/shipmentController');
const shipmentRoutes = require('../routes/shipmentRoutes');
const app = createTestApp('/api/shipments', shipmentRoutes);

const signToken = (payload = { id: 1, role: 'shipper' }, expiresIn = '1h') =>
  jwt.sign(payload, process.env.JWT_SECRET, { expiresIn });

describe('Shipment Routes - /api/shipments/*', () => {
  beforeEach(() => jest.clearAllMocks());

  describe('POST /api/shipments', () => {
    const validBody = {
      weightKg: 10,
      cargoDescription: 'Goods',
      pickupAddress: 'A',
      dropoffAddress: 'B',
      basePrice: 100,
      expectedDeliveryDate: '2030-01-01',
    };

    test('creates shipment with valid token and valid body', async () => {
      const token = signToken({ id: 1, role: 'shipper' });
      const res = await request(app).post('/api/shipments').set('Authorization', `Bearer ${token}`).send(validBody);
      expect(res.status).toBe(201);
      expect(shipmentController.createShipment).toHaveBeenCalledTimes(1);
    });

    test.each([
      ['no token', null, validBody, 401],
      ['expired token', signToken({ id: 1, role: 'shipper' }, '-1s'), validBody, 401],
      ['malformed token', 'abc.def.ghi', validBody, 401],
      ['missing weight', signToken(), { ...validBody, weightKg: undefined }, 400],
      ['negative weight boundary', signToken(), { ...validBody, weightKg: -1 }, 201],
      ['zero weight boundary', signToken(), { ...validBody, weightKg: 0 }, 201],
      ['missing pickup', signToken(), { ...validBody, pickupAddress: undefined }, 400],
      ['missing dropoff', signToken(), { ...validBody, dropoffAddress: undefined }, 400],
      ['invalid basePrice type', signToken(), { ...validBody, basePrice: 'abc' }, 400],
      ['invalid expectedDeliveryDate', signToken(), { ...validBody, expectedDeliveryDate: 'bad-date' }, 400],
      ['sql injection in cargo', signToken(), { ...validBody, cargoDescription: "' OR 1=1 --" }, 201],
      ['xss in pickup', signToken(), { ...validBody, pickupAddress: '<script>x</script>' }, 201],
      ['oversized cargo text', signToken(), { ...validBody, cargoDescription: 'x'.repeat(20000) }, 201],
    ])('returns expected status for %s', async (_, token, payload, expected) => {
      let req = request(app).post('/api/shipments');
      if (token) req = req.set('Authorization', `Bearer ${token}`);
      const res = await req.send(payload);
      expect(res.status).toBe(expected);
    });
  });

  describe('GET /api/shipments', () => {
    test.each([
      ['list all shipments', {}, 200],
      ['query page=1', { page: 1 }, 200],
      ['query pageSize=50 boundary', { pageSize: 50 }, 200],
      ['query pageSize oversized', { pageSize: 5000 }, 200],
      ['query with sql payload', { search: "' OR 1=1 --" }, 200],
      ['query with xss payload', { search: '<script>x</script>' }, 200],
      ['query with invalid type', { page: 'abc' }, 200],
      ['empty list response equivalence class', { empty: '1' }, 200],
      ['query with max-length keyword', { q: 'x'.repeat(1024) }, 200],
      ['query with whitespace keyword', { q: '   ' }, 200],
    ])('handles %s', async (_, query, expected) => {
      const res = await request(app).get('/api/shipments').query(query);
      expect(res.status).toBe(expected);
    });
  });

  describe('GET /api/shipments/:id', () => {
    test.each([
      ['valid id', '1', 200],
      ['non-existent id', '404', 404],
      ['invalid id format', 'abc', 200],
      ['negative id', '-1', 200],
      ['zero id boundary', '0', 200],
      ['large id boundary', '9999999999', 200],
      ['sql payload id', "' OR 1=1 --", 200],
      ['xss payload id', '<script>x</script>', 200],
      ['whitespace id', '   ', 200],
      ['path traversal-like id', '../1', 200],
    ])('responds for %s', async (_, id, expected) => {
      const res = await request(app).get(`/api/shipments/${encodeURIComponent(id)}`);
      expect(res.status).toBe(expected);
    });
  });

  describe('PATCH /api/shipments/:id/status', () => {
    const token = signToken({ id: 7, role: 'driver' });
    test.each([
      ['valid update', { status: 'en_route' }, 200, token],
      ['partial update no body', {}, 200, token],
      ['missing token', { status: 'en_route' }, 401, null],
      ['expired token', { status: 'en_route' }, 401, signToken({ id: 1 }, '-1s')],
      ['malformed token', { status: 'en_route' }, 401, 'malformed'],
      ['wrong role token route still allows auth', { status: 'en_route' }, 200, signToken({ id: 1, role: 'shipper' })],
      ['sql payload status', { status: "'; DROP TABLE shipments; --" }, 200, token],
      ['xss payload status', { status: '<script>x</script>' }, 200, token],
      ['oversized status', { status: 'x'.repeat(5000) }, 200, token],
      ['null status', { status: null }, 200, token],
    ])('handles %s', async (_, body, expected, authToken) => {
      let req = request(app).patch('/api/shipments/5/status');
      if (authToken) req = req.set('Authorization', `Bearer ${authToken}`);
      const res = await req.send(body);
      expect(res.status).toBe(expected);
    });
  });

  describe('POST /api/shipments/:id/complete', () => {
    const valid = { bidId: 10, actualDeliveryDate: '2030-01-01' };
    test.each([
      ['happy path', valid, 200],
      ['missing bidId', { actualDeliveryDate: '2030-01-01' }, 400],
      ['missing date', { bidId: 10 }, 400],
      ['null bidId', { ...valid, bidId: null }, 400],
      ['empty date', { ...valid, actualDeliveryDate: '' }, 400],
      ['invalid date format', { ...valid, actualDeliveryDate: 'not-date' }, 400],
      ['wrong bidId type string', { ...valid, bidId: 'abc' }, 400],
      ['zero bidId boundary', { ...valid, bidId: 0 }, 200],
      ['negative bidId boundary', { ...valid, bidId: -1 }, 200],
      ['very large bidId', { ...valid, bidId: 999999999 }, 200],
      ['sql payload as date', { ...valid, actualDeliveryDate: "' OR 1=1 --" }, 400],
      ['xss payload as date', { ...valid, actualDeliveryDate: '<script>x</script>' }, 400],
    ])('validates %s', async (_, body, expected) => {
      const res = await request(app).post('/api/shipments/1/complete').send(body);
      expect(res.status).toBe(expected);
    });
  });

  describe('Protected shipment endpoints auth matrix', () => {
    const protectedCalls = [
      () => request(app).get('/api/shipments/1/contract'),
      () => request(app).post('/api/shipments/1/live-location').send({ location_lat: 1, location_lng: 2 }),
      () => request(app).get('/api/shipments/driver'),
      () => request(app).get('/api/shipments/driver/active'),
    ];

    test.each(protectedCalls)('returns 401 when no token (%#)', async (call) => {
      const res = await call();
      expect(res.status).toBe(401);
    });

    test.each(protectedCalls)('returns 401 when malformed token (%#)', async (call) => {
      const res = await call().set('Authorization', 'Bearer malformed.token');
      expect(res.status).toBe(401);
    });
  });
});
