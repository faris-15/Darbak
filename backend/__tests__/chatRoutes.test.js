const request = require('supertest');
const jwt = require('jsonwebtoken');
const { createTestApp } = require('./helpers/createTestApp');

jest.mock('../controllers/chatController', () => ({
  listMyConversations: jest.fn((req, res) => res.status(200).json([])),
  getShipmentChat: jest.fn((req, res) => {
    if (req.params.shipmentId === '404') return res.status(404).json({ message: 'not found' });
    return res.status(200).json([]);
  }),
  sendShipmentMessage: jest.fn((req, res) => {
    if (req.body.shipmentId === 404) return res.status(404).json({ message: 'not found' });
    if (req.body.message && req.body.message.length > 2048) return res.status(400).json({ message: 'too long' });
    return res.status(201).json({ success: true });
  }),
}));

const routes = require('../routes/chatRoutes');
const app = createTestApp('/api/chat', routes);
const signToken = (payload = { id: 1, role: 'driver' }, expiresIn = '1h') =>
  jwt.sign(payload, process.env.JWT_SECRET, { expiresIn });

describe('Chat Routes - /api/chat/*', () => {
  describe('GET /api/chat/conversations/me', () => {
    const call = (token) => {
      let req = request(app).get('/api/chat/conversations/me');
      if (token) req = req.set('Authorization', `Bearer ${token}`);
      return req;
    };
    test('happy path', async () => expect((await call(signToken())).status).toBe(200));
    test('no token -> 401', async () => expect((await call(null)).status).toBe(401));
    test('expired token -> 401', async () => expect((await call(signToken({}, '-1s'))).status).toBe(401));
    test('malformed token -> 401', async () => expect((await call('bad.token')).status).toBe(401));
    test('wrong role still authenticated', async () =>
      expect((await call(signToken({ id: 1, role: 'shipper' }))).status).toBe(200));
    test('sql query payload safe', async () => expect((await call(signToken()).query({ q: "' OR 1=1 --" })).status).not.toBe(500));
    test('xss query payload safe', async () => expect((await call(signToken()).query({ q: '<script>x</script>' })).status).not.toBe(500));
    test('boundary query limit', async () => expect([200, 400]).toContain((await call(signToken()).query({ limit: 0 })).status));
    test('oversized query safe', async () => expect((await call(signToken()).query({ q: 'x'.repeat(2000) })).status).not.toBe(500));
    test('whitespace query safe', async () => expect((await call(signToken()).query({ q: '   ' })).status).not.toBe(500));
  });

  describe('GET /api/chat/:shipmentId', () => {
    const call = (id, token) => {
      let req = request(app).get(`/api/chat/${encodeURIComponent(id)}`);
      if (token) req = req.set('Authorization', `Bearer ${token}`);
      return req;
    };
    test('happy path', async () => expect((await call('1', signToken())).status).toBe(200));
    test('no token -> 401', async () => expect((await call('1', null)).status).toBe(401));
    test('expired token -> 401', async () => expect((await call('1', signToken({}, '-1s'))).status).toBe(401));
    test('malformed token -> 401', async () => expect((await call('1', 'bad.token')).status).toBe(401));
    test('wrong role still authenticated', async () =>
      expect((await call('1', signToken({ id: 1, role: 'shipper' }))).status).toBe(200));
    test('not found -> 404', async () => expect((await call('404', signToken())).status).toBe(404));
    test('sql injection id safe', async () => expect((await call("' OR 1=1 --", signToken())).status).not.toBe(500));
    test('xss id safe', async () => expect((await call('<script>x</script>', signToken())).status).not.toBe(500));
    test('boundary zero id safe', async () => expect((await call('0', signToken())).status).not.toBe(500));
    test('boundary oversized id safe', async () => expect((await call('9'.repeat(512), signToken())).status).not.toBe(500));
  });

  describe('POST /api/chat/send', () => {
    const valid = { shipmentId: 1, receiverId: 2, message: 'hi' };
    const call = (body, token) => {
      let req = request(app).post('/api/chat/send');
      if (token) req = req.set('Authorization', `Bearer ${token}`);
      return req.send(body);
    };
    test('happy path', async () => expect((await call(valid, signToken())).status).toBe(201));
    test('no token -> 401', async () => expect((await call(valid, null)).status).toBe(401));
    test('expired token -> 401', async () => expect((await call(valid, signToken({}, '-1s'))).status).toBe(401));
    test('malformed token -> 401', async () => expect((await call(valid, 'bad.token')).status).toBe(401));
    test('wrong role still accepted route-wise', async () =>
      expect((await call(valid, signToken({ id: 2, role: 'shipper' }))).status).toBe(201));
    test('missing fields -> 400', async () => expect((await call({ shipmentId: 1 }, signToken())).status).toBe(400));
    test('not found -> 404', async () => expect((await call({ ...valid, shipmentId: 404 }, signToken())).status).toBe(404));
    test('sql injection message safe', async () => expect((await call({ ...valid, message: "' OR 1=1 --" }, signToken())).status).not.toBe(500));
    test('xss message safe', async () => expect((await call({ ...valid, message: '<script>x</script>' }, signToken())).status).not.toBe(500));
    test('boundary message oversized -> 400', async () => expect((await call({ ...valid, message: 'x'.repeat(3000) }, signToken())).status).toBe(400));
  });
});
