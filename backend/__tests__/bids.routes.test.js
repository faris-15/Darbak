const request = require('supertest');
const jwt = require('jsonwebtoken');
const { createTestApp } = require('./helpers/createTestApp');

jest.mock('../controllers/bidController', () => ({
  createBid: jest.fn((req, res) => {
    if (req.user?.role !== 'driver') return res.status(403).json({ message: 'forbidden role' });
    if (req.body.shipmentId === 404) return res.status(404).json({ message: 'shipment not found' });
    if (req.body.shipmentId === 409) return res.status(409).json({ message: 'duplicate bid' });
    if (Number(req.body.bidAmount) <= 0) return res.status(400).json({ message: 'bidAmount must be > 0' });
    if (Number(req.body.estimatedDays) <= 0) return res.status(400).json({ message: 'estimatedDays must be > 0' });
    if (typeof req.body.note === 'string' && req.body.note.length > 1024) {
      return res.status(400).json({ message: 'note too large' });
    }
    return res.status(201).json({ id: 1, success: true });
  }),
  getBidsByShipment: jest.fn((req, res) => {
    if (req.params.shipmentId === '404') return res.status(404).json({ message: 'not found' });
    if (req.params.shipmentId === '1') return res.status(200).json([{ id: 11, bid_amount: 99 }]);
    return res.status(200).json([]);
  }),
  acceptBid: jest.fn((req, res) => {
    if (req.user?.role !== 'shipper') return res.status(403).json({ message: 'forbidden role' });
    if (req.params.bidId === '404') return res.status(404).json({ message: 'not found' });
    if (req.params.bidId === '409') return res.status(409).json({ message: 'already accepted' });
    if (req.params.bidId === '403-owner') return res.status(403).json({ message: 'not owner shipment' });
    return res.status(200).json({ success: true });
  }),
}));

const bidRoutes = require('../routes/bidRoutes');
const app = createTestApp('/api/bids', bidRoutes);

const signToken = (payload = { id: 1, role: 'driver' }, expiresIn = '1h') =>
  jwt.sign(payload, process.env.JWT_SECRET, { expiresIn });

describe('Bid Routes - /api/bids/*', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('POST /api/bids', () => {
    const valid = { shipmentId: 1, bidAmount: 10, estimatedDays: 2, note: 'valid note' };
    const driverToken = signToken({ id: 2, role: 'driver' });

    test.each([
      ['happy path driver creates bid', valid, driverToken, 201],
      ['missing shipmentId', { bidAmount: 10, estimatedDays: 2 }, driverToken, 400],
      ['missing bidAmount', { shipmentId: 1, estimatedDays: 2 }, driverToken, 400],
      ['missing estimatedDays', { shipmentId: 1, bidAmount: 10 }, driverToken, 400],
      ['missing all fields', {}, driverToken, 400],
      ['null shipmentId', { ...valid, shipmentId: null }, driverToken, 400],
      ['null bidAmount', { ...valid, bidAmount: null }, driverToken, 400],
      ['empty body', undefined, driverToken, 400],
      ['negative bidAmount boundary', { ...valid, bidAmount: -1 }, driverToken, 400],
      ['zero bidAmount boundary', { ...valid, bidAmount: 0 }, driverToken, 400],
      ['bidAmount = 1 boundary passes', { ...valid, bidAmount: 1 }, driverToken, 201],
      ['estimatedDays = 0 boundary', { ...valid, estimatedDays: 0 }, driverToken, 400],
      ['estimatedDays = 1 boundary passes', { ...valid, estimatedDays: 1 }, driverToken, 201],
      ['negative estimatedDays', { ...valid, estimatedDays: -5 }, driverToken, 400],
      ['wrong type bidAmount string', { ...valid, bidAmount: 'ten' }, driverToken, 400],
      ['wrong type estimatedDays string', { ...valid, estimatedDays: 'two' }, driverToken, 400],
      ['SQL injection in shipmentId', { ...valid, shipmentId: "' OR 1=1 --" }, driverToken, 400],
      ['XSS payload in note field is handled safely', { ...valid, note: '<script>alert(1)</script>' }, driverToken, 201],
      ['oversized note field', { ...valid, note: 'x'.repeat(2048) }, driverToken, 400],
      ['non-driver role shipper token', valid, signToken({ id: 5, role: 'shipper' }), 403],
      ['no token', valid, null, 401],
      ['expired token', valid, signToken({ id: 2, role: 'driver' }, '-1s'), 401],
      ['malformed token', valid, 'malformed.token', 401],
      ['duplicate bid on same shipment', { ...valid, shipmentId: 409 }, driverToken, 409],
      ['bid on non-existent shipment', { ...valid, shipmentId: 404 }, driverToken, 404],
      ['whitespace note accepted', { ...valid, note: '   ' }, driverToken, 201],
      ['large numeric bid string stays in safe handled response class', { ...valid, bidAmount: '9'.repeat(4000) }, driverToken, 201],
      ['extra unknown field ignored', { ...valid, unknown: 'field' }, driverToken, 201],
    ])('%s', async (_, payload, token, expected) => {
      let req = request(app).post('/api/bids');
      if (token) req = req.set('Authorization', `Bearer ${token}`);
      if (payload === undefined) {
        req = req.send();
      } else {
        req = req.send(payload);
      }
      const res = await req;
      expect(res.status).toBe(expected);
    });
  });

  describe('GET /api/bids/shipment/:shipmentId', () => {
    test('valid shipmentId with bids returns 200 and array', async () => {
      const res = await request(app).get('/api/bids/shipment/1');
      expect(res.status).toBe(200);
      expect(Array.isArray(res.body)).toBe(true);
      expect(res.body.length).toBeGreaterThan(0);
    });

    test('valid shipmentId with no bids returns 200 and []', async () => {
      const res = await request(app).get('/api/bids/shipment/2');
      expect(res.status).toBe(200);
      expect(res.body).toEqual([]);
    });

    test.each([
      ['non-existent shipmentId 404', '404', 404],
      ['invalid id format abc', 'abc', 200],
      ['negative id', '-1', 200],
      ['zero id boundary', '0', 200],
      ['oversized id', '9999999999999999999', 200],
      ['SQL payload id', "' OR 1=1 --", 200],
      ['XSS payload id', '<script>alert(1)</script>', 200],
      ['no token route remains public', '1', 200],
      ['whitespace id', '   ', 200],
      ['path traversal-like id', '../1', 200],
      ['unicode id', '١٢٣', 200],
    ])('%s', async (_, shipmentId, expected) => {
      const res = await request(app).get(`/api/bids/shipment/${encodeURIComponent(shipmentId)}`);
      expect(res.status).toBe(expected);
    });
  });

  describe('POST /api/bids/:bidId/accept', () => {
    const shipperToken = signToken({ id: 9, role: 'shipper' });

    test.each([
      ['valid shipper accepts valid bid', '10', shipperToken, 200],
      ['non-shipper driver tries to accept', '10', signToken({ id: 3, role: 'driver' }), 403],
      ['bidId 404 not found', '404', shipperToken, 404],
      ['bidId 409 already accepted', '409', shipperToken, 409],
      ['no token', '10', null, 401],
      ['expired token', '10', signToken({ id: 9, role: 'shipper' }, '-1s'), 401],
      ['malformed token', '10', 'bad.token', 401],
      ['wrong role token admin', '10', signToken({ id: 1, role: 'admin' }), 403],
      ['invalid bidId format', 'abc', shipperToken, 200],
      ['negative bidId', '-2', shipperToken, 200],
      ['zero bidId boundary', '0', shipperToken, 200],
      ['SQL payload bidId', "' OR 1=1 --", shipperToken, 200],
      ['XSS payload bidId', '<script>alert(1)</script>', shipperToken, 200],
      ['oversized bidId', '9'.repeat(4096), shipperToken, 200],
      ['accept bid for another user shipment', '403-owner', shipperToken, 403],
      ['whitespace bidId', '   ', shipperToken, 200],
      ['unicode bidId', '١٢٣', shipperToken, 200],
    ])('%s', async (_, bidId, token, expected) => {
      let req = request(app).post(`/api/bids/${encodeURIComponent(bidId)}/accept`);
      if (token) req = req.set('Authorization', `Bearer ${token}`);
      const res = await req.send({});
      expect(res.status).toBe(expected);
    });
  });

  describe('PUT /api/bids/:bidId/accept (method not implemented)', () => {
    test.each([
      ['put valid bid id returns route not found', '10', signToken({ id: 1, role: 'shipper' }), 404],
      ['put without token also route not found', '10', null, 404],
      ['put malformed token route not found', '10', 'bad.token', 404],
      ['put invalid bid id route not found', 'abc', signToken({ id: 1, role: 'shipper' }), 404],
    ])('%s', async (_, bidId, token, expected) => {
      let req = request(app).put(`/api/bids/${encodeURIComponent(bidId)}/accept`);
      if (token) req = req.set('Authorization', `Bearer ${token}`);
      const res = await req.send({});
      expect(res.status).toBe(expected);
    });
  });

  describe('DELETE /api/bids/:bidId (if route exists)', () => {
    test.each([
      ['valid cancel own bid when route absent returns 404', '1', signToken({ id: 1, role: 'driver' }), 404],
      ['cancel already accepted bid route absent', '409', signToken({ id: 1, role: 'driver' }), 404],
      ['cancel another drivers bid route absent', '403', signToken({ id: 1, role: 'driver' }), 404],
      ['bid not found route absent', '404', signToken({ id: 1, role: 'driver' }), 404],
      ['no token route absent', '1', null, 404],
      ['invalid id route absent', 'abc', signToken({ id: 1, role: 'driver' }), 404],
      ['sql payload id route absent', "' OR 1=1 --", signToken({ id: 1, role: 'driver' }), 404],
      ['xss payload id route absent', '<script>x</script>', signToken({ id: 1, role: 'driver' }), 404],
    ])('%s', async (_, bidId, token, expected) => {
      let req = request(app).delete(`/api/bids/${encodeURIComponent(bidId)}`);
      if (token) req = req.set('Authorization', `Bearer ${token}`);
      const res = await req.send();
      expect(res.status).toBe(expected);
    });
  });
});
