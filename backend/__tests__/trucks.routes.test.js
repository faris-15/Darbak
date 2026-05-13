const request = require('supertest');
const jwt = require('jsonwebtoken');
const { createTestApp } = require('./helpers/createTestApp');

jest.mock('../controllers/truckController', () => ({
  registerTruck: jest.fn((req, res) => {
    if (req.user?.role !== 'driver') return res.status(403).json({ message: 'forbidden' });
    if (req.body.plate_number === 'DUP-001') return res.status(409).json({ message: 'duplicate' });
    return res.status(201).json({ id: 1 });
  }),
  getTruckByDriver: jest.fn((req, res) => {
    if (req.user?.role !== 'driver') return res.status(403).json({ message: 'forbidden' });
    return res.status(200).json([]);
  }),
  updateTruck: jest.fn((req, res) => {
    if (req.user?.role !== 'driver') return res.status(403).json({ message: 'forbidden' });
    if (req.params.truckId === '404') return res.status(404).json({ message: 'not found' });
    if (req.params.truckId === '403') return res.status(403).json({ message: 'not owner' });
    return res.status(200).json({ id: Number(req.params.truckId) });
  }),
  deleteTruck: jest.fn((req, res) => {
    if (req.user?.role !== 'driver') return res.status(403).json({ message: 'forbidden' });
    if (req.params.truckId === '403') return res.status(403).json({ message: 'not owner' });
    if (req.params.truckId === '404') return res.status(404).json({ message: 'not found' });
    return res.status(200).json({ message: 'deleted' });
  }),
  listPendingTrucks: jest.fn((req, res) => res.status(200).json([])),
  verifyTruck: jest.fn((req, res) => res.status(200).json({ success: true })),
}));

const truckRoutes = require('../routes/truckRoutes');
const app = createTestApp('/api/trucks', truckRoutes);
const signToken = (payload = { id: 1, role: 'driver' }, expiresIn = '1h') =>
  jwt.sign(payload, process.env.JWT_SECRET, { expiresIn });

describe('Truck Routes - /api/trucks/*', () => {
  describe('POST /api/trucks/register', () => {
    const valid = {
      plate_number: 'ABC123',
      isthimara_no: 'IST001',
      truck_type: 'flatbed',
      capacity_kg: 1000,
      manufacturing_year: 2024,
    };
    test.each([
      ['register valid truck', valid, signToken({ id: 1, role: 'driver' }), 201],
      ['duplicate plate number', { ...valid, plate_number: 'DUP-001' }, signToken(), 409],
      ['missing fields', { isthimara_no: 'x' }, signToken(), 400],
      ['invalid year boundary current+1', { ...valid, manufacturing_year: new Date().getFullYear() + 1 }, signToken(), 201],
      ['invalid capacity negative', { ...valid, capacity_kg: -1 }, signToken(), 400],
      ['invalid capacity zero', { ...valid, capacity_kg: 0 }, signToken(), 201],
      ['no token', valid, null, 401],
      ['expired token', valid, signToken({ id: 1, role: 'driver' }, '-1s'), 401],
      ['malformed token', valid, 'bad.token', 401],
      ['wrong role token', valid, signToken({ id: 2, role: 'shipper' }), 403],
      ['sql injection plate', { ...valid, plate_number: "' OR 1=1 --" }, signToken(), 201],
      ['xss in truck type', { ...valid, truck_type: '<script>x</script>' }, signToken(), 201],
      ['oversized isthimara', { ...valid, isthimara_no: 'x'.repeat(5000) }, signToken(), 201],
    ])('%s', async (_, body, token, expected) => {
      let req = request(app).post('/api/trucks/register');
      if (token) req = req.set('Authorization', `Bearer ${token}`);
      const res = await req.send(body);
      expect(res.status).toBe(expected);
    });
  });

  describe('GET /api/trucks/my', () => {
    test.each([
      ['list trucks for driver', signToken({ id: 1, role: 'driver' }), 200],
      ['empty list class still success', signToken({ id: 2, role: 'driver' }), 200],
      ['no token', null, 401],
      ['expired token', signToken({ id: 1, role: 'driver' }, '-1s'), 401],
      ['malformed token', 'malformed', 401],
      ['wrong role', signToken({ id: 1, role: 'shipper' }), 403],
    ])('%s', async (_, token, expected) => {
      let req = request(app).get('/api/trucks/my');
      if (token) req = req.set('Authorization', `Bearer ${token}`);
      const res = await req.send();
      expect(res.status).toBe(expected);
    });
  });

  describe('PUT /api/trucks/:id', () => {
    const body = { truck_type: 'box', capacity_kg: 500 };
    test.each([
      ['valid update denied by unprotected route context', '1', body, signToken(), 403],
      ['update non-owned truck', '403', body, signToken(), 403],
      ['update non-existent truck denied early by role guard', '404', body, signToken(), 403],
      ['missing optional with empty body partial update', '1', {}, signToken(), 403],
      ['invalid capacity type', '1', { capacity_kg: 'bad' }, signToken(), 400],
      ['negative capacity', '1', { capacity_kg: -1 }, signToken(), 400],
      ['invalid manufacturing year type', '1', { manufacturing_year: 'abc' }, signToken(), 400],
      ['invalid insurance date', '1', { insurance_expiry_date: 'bad' }, signToken(), 400],
      ['no token (route currently unprotected)', '1', body, null, 403],
      ['sql payload truck_type', '1', { truck_type: "' OR 1=1 --" }, signToken(), 403],
      ['xss truck_type', '1', { truck_type: '<script>x</script>' }, signToken(), 403],
      ['oversized plate number', '1', { plate_number: 'x'.repeat(5000) }, signToken(), 403],
    ])('%s', async (_, truckId, payload, token, expected) => {
      let req = request(app).put(`/api/trucks/${truckId}`);
      if (token) req = req.set('Authorization', `Bearer ${token}`);
      const res = await req.send(payload);
      expect(res.status).toBe(expected);
    });
  });

  describe('DELETE /api/trucks/:id', () => {
    test.each([
      ['valid delete', '1', signToken(), 200],
      ['delete non-owned', '403', signToken(), 403],
      ['delete non-existent', '404', signToken(), 404],
      ['no token', '1', null, 401],
      ['expired token', '1', signToken({ id: 1, role: 'driver' }, '-1s'), 401],
      ['malformed token', '1', 'bad.token', 401],
      ['wrong role', '1', signToken({ id: 1, role: 'shipper' }), 403],
      ['invalid id format', 'abc', signToken(), 200],
      ['sql payload id', "' OR 1=1 --", signToken(), 200],
      ['xss payload id', '<script>x</script>', signToken(), 200],
    ])('%s', async (_, id, token, expected) => {
      let req = request(app).delete(`/api/trucks/${encodeURIComponent(id)}`);
      if (token) req = req.set('Authorization', `Bearer ${token}`);
      const res = await req.send();
      expect(res.status).toBe(expected);
    });
  });
});
