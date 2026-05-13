const request = require('supertest');
const { createTestApp } = require('./helpers/createTestApp');

jest.mock('../controllers/biddingRoomController', () => ({
  enterBiddingRoom: jest.fn((req, res) => {
    if (req.params.shipmentId === '404') return res.status(404).json({ message: 'not found' });
    return res.status(200).json({ success: true });
  }),
  exitBiddingRoom: jest.fn((req, res) => {
    if (req.params.shipmentId === '404') return res.status(404).json({ message: 'not found' });
    return res.status(200).json({ success: true });
  }),
  getRoomStatus: jest.fn((req, res) => {
    if (req.params.shipmentId === '404') return res.status(404).json({ message: 'not found' });
    return res.status(200).json({ total_bids: 0 });
  }),
}));

const routes = require('../routes/biddingRoomRoutes');
const app = createTestApp('/api/bidding-rooms', routes);

describe('BiddingRoom Routes - /api/bidding-rooms/*', () => {
  describe.each([
    ['POST', '/rooms/1/enter'],
    ['POST', '/rooms/1/exit'],
    ['GET', '/rooms/1/status'],
  ])('%s %s', (method, path) => {
    const call = (suffix = '', body = {}) => {
      const p = suffix ? path.replace('/1/', `/${suffix}/`) : path;
      let req = request(app)[method.toLowerCase()](`/api/bidding-rooms${p}`);
      if (method !== 'GET') req = req.send(body);
      return req;
    };

    test('happy path', async () => {
      const res = await call();
      expect(res.status).toBe(200);
    });
    test('not found returns 404', async () => {
      const res = await call('404');
      expect(res.status).toBe(404);
    });
    test('missing fields safe', async () => {
      const res = await call('', {});
      expect([200, 400]).toContain(res.status);
    });
    test('invalid id format safe', async () => {
      const res = await call('abc');
      expect(res.status).not.toBe(500);
    });
    test('negative id boundary safe', async () => {
      const res = await call('-1');
      expect(res.status).not.toBe(500);
    });
    test('zero id boundary safe', async () => {
      const res = await call('0');
      expect(res.status).not.toBe(500);
    });
    test('oversized id boundary safe', async () => {
      const res = await call('9'.repeat(512));
      expect(res.status).not.toBe(500);
    });
    test('sql injection payload safe', async () => {
      const res = await call("' OR 1=1 --");
      expect(res.status).not.toBe(500);
    });
    test('xss payload safe', async () => {
      const res = await call('<script>alert(1)</script>');
      expect(res.status).not.toBe(500);
    });
    test('whitespace id safe', async () => {
      const res = await call('   ');
      expect(res.status).not.toBe(500);
    });
  });
});
