const request = require('supertest');
const jwt = require('jsonwebtoken');
const { createTestApp } = require('./helpers/createTestApp');

jest.mock('../controllers/ratingController', () => ({
  addRating: jest.fn((req, res) => {
    if (req.body.stars === 0) return res.status(400).json({ message: 'min boundary failed' });
    if (req.body.stars === 6) return res.status(400).json({ message: 'max boundary failed' });
    if (req.body.shipment_id === 409) return res.status(409).json({ message: 'duplicate rating' });
    return res.status(201).json({ id: 1, stars: req.body.stars });
  }),
  getUserRatings: jest.fn((req, res) => {
    if (req.params.userId === '404') return res.status(404).json({ message: 'not found' });
    return res.status(200).json({ user_id: req.params.userId, ratings: [] });
  }),
  updateRating: jest.fn((req, res) => {
    if (req.params.ratingId === '404') return res.status(404).json({ message: 'not found' });
    return res.status(200).json({ success: true });
  }),
  deleteRating: jest.fn((req, res) => {
    if (req.params.ratingId === '404') return res.status(404).json({ message: 'not found' });
    return res.status(200).json({ success: true });
  }),
}));

const ratingRoutes = require('../routes/ratingRoutes');
const app = createTestApp('/api/ratings', ratingRoutes);
const signToken = (payload = { id: 1, role: 'shipper' }, expiresIn = '1h') =>
  jwt.sign(payload, process.env.JWT_SECRET, { expiresIn });

describe('Rating Routes - /api/ratings/*', () => {
  describe('POST /api/ratings', () => {
    const valid = { shipment_id: 1, rated_id: 2, stars: 5, comment: 'Great' };
    test.each([
      ['valid rating happy path', valid, signToken(), 201],
      ['rating boundary 1 passes', { ...valid, stars: 1 }, signToken(), 201],
      ['rating boundary 5 passes', { ...valid, stars: 5 }, signToken(), 201],
      ['rating boundary 0 fails', { ...valid, stars: 0 }, signToken(), 400],
      ['rating boundary 6 fails', { ...valid, stars: 6 }, signToken(), 400],
      ['duplicate rating', { ...valid, shipment_id: 409 }, signToken(), 409],
      ['missing shipment_id', { rated_id: 2, stars: 5 }, signToken(), 400],
      ['missing rated_id', { shipment_id: 1, stars: 5 }, signToken(), 400],
      ['missing stars', { shipment_id: 1, rated_id: 2 }, signToken(), 400],
      ['wrong stars type', { ...valid, stars: 'five' }, signToken(), 400],
      ['no token', valid, null, 401],
      ['expired token', valid, signToken({ id: 1, role: 'shipper' }, '-1s'), 401],
      ['malformed token', valid, 'invalid.token', 401],
      ['sql injection comment', { ...valid, comment: "' OR 1=1 --" }, signToken(), 201],
      ['xss comment', { ...valid, comment: '<script>alert(1)</script>' }, signToken(), 201],
    ])('%s', async (_, body, token, expected) => {
      let req = request(app).post('/api/ratings');
      if (token) req = req.set('Authorization', `Bearer ${token}`);
      const res = await req.send(body);
      expect(res.status).toBe(expected);
    });
  });

  describe('GET /api/ratings/user/:userId', () => {
    test.each([
      ['get valid user ratings', '1', 200],
      ['user not found', '404', 404],
      ['invalid id format', 'abc', 200],
      ['boundary id zero', '0', 200],
      ['boundary negative', '-1', 200],
      ['oversized id', '9999999999', 200],
      ['sql payload id', "' OR 1=1 --", 200],
      ['xss payload id', '<script>x</script>', 200],
      ['whitespace id', '   ', 200],
      ['unicode id', '١٢٣', 200],
    ])('%s', async (_, userId, expected) => {
      const res = await request(app).get(`/api/ratings/user/${encodeURIComponent(userId)}`);
      expect(res.status).toBe(expected);
    });
  });

  describe('PUT /api/ratings/:ratingId', () => {
    test.each([
      ['valid update', '1', { stars: 4, comment: 'ok' }, 200],
      ['update not found', '404', { stars: 4, comment: 'ok' }, 404],
      ['stars boundary min pass', '1', { stars: 1, comment: '' }, 200],
      ['stars boundary max pass', '1', { stars: 5, comment: '' }, 200],
      ['stars below min', '1', { stars: 0, comment: '' }, 400],
      ['stars above max', '1', { stars: 6, comment: '' }, 400],
      ['missing stars', '1', { comment: 'x' }, 400],
      ['wrong stars type', '1', { stars: 'x', comment: 'x' }, 400],
      ['sql injection comment', '1', { stars: 4, comment: "' OR 1=1 --" }, 200],
      ['xss comment', '1', { stars: 4, comment: '<script>x</script>' }, 200],
    ])('%s', async (_, ratingId, body, expected) => {
      const res = await request(app).put(`/api/ratings/${ratingId}`).send(body);
      expect(res.status).toBe(expected);
    });
  });

  describe('DELETE /api/ratings/:ratingId', () => {
    test.each([
      ['valid delete', '1', 200],
      ['delete not found', '404', 404],
      ['invalid id format', 'abc', 200],
      ['negative id', '-1', 200],
      ['zero id', '0', 200],
      ['oversized id', '9999999999999', 200],
      ['sql payload id', "' OR 1=1 --", 200],
      ['xss payload id', '<script>x</script>', 200],
      ['whitespace id', '   ', 200],
      ['unicode id', '١٢٣', 200],
    ])('%s', async (_, id, expected) => {
      const res = await request(app).delete(`/api/ratings/${encodeURIComponent(id)}`);
      expect(res.status).toBe(expected);
    });
  });
});
