const request = require('supertest');
const { createTestApp } = require('./helpers/createTestApp');

jest.mock('../controllers/payoutController', () => ({
  computePayout: jest.fn((req, res) => {
    if (req.body.totalAmount === 404) return res.status(404).json({ message: 'not found' });
    return res.status(200).json({ payout: 100 });
  }),
}));

const routes = require('../routes/payoutRoutes');
const app = createTestApp('/api/payout', routes);

describe('Payout Routes - /api/payout/*', () => {
  describe('POST /api/payout', () => {
    const valid = { totalAmount: 1000, edt: '2030-01-01', actualDeliveryDate: '2030-01-03' };
    test('happy path', async () => expect((await request(app).post('/api/payout').send(valid)).status).toBe(200));
    test('missing totalAmount -> 400', async () => expect((await request(app).post('/api/payout').send({ ...valid, totalAmount: undefined })).status).toBe(400));
    test('missing edt -> 400', async () => expect((await request(app).post('/api/payout').send({ ...valid, edt: undefined })).status).toBe(400));
    test('missing actualDeliveryDate -> 400', async () => expect((await request(app).post('/api/payout').send({ ...valid, actualDeliveryDate: undefined })).status).toBe(400));
    test('not found -> 404', async () => expect((await request(app).post('/api/payout').send({ ...valid, totalAmount: 404 })).status).toBe(404));
    test('sql injection in totalAmount -> 400', async () => expect((await request(app).post('/api/payout').send({ ...valid, totalAmount: "' OR 1=1 --" })).status).toBe(400));
    test('xss payload in edt -> 400', async () => expect((await request(app).post('/api/payout').send({ ...valid, edt: '<script>x</script>' })).status).toBe(400));
    test('boundary totalAmount zero accepted route-level', async () => expect([200, 400]).toContain((await request(app).post('/api/payout').send({ ...valid, totalAmount: 0 })).status));
    test('boundary large totalAmount safe', async () => expect((await request(app).post('/api/payout').send({ ...valid, totalAmount: 999999999999 })).status).not.toBe(500));
    test('malformed json -> 400', async () => {
      const res = await request(app).post('/api/payout').set('Content-Type', 'application/json').send('{"totalAmount":');
      expect(res.status).toBe(400);
    });
  });
});
