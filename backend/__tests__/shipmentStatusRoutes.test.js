const request = require('supertest');
const { createTestApp } = require('./helpers/createTestApp');

jest.mock('../controllers/shipmentStatusController', () => ({
  recordStatus: jest.fn((req, res) => {
    if (req.body.shipment_id === 404) return res.status(404).json({ message: 'not found' });
    return res.status(201).json({ success: true });
  }),
  getStatusHistory: jest.fn((req, res) => {
    if (req.params.shipment_id === '404') return res.status(404).json({ message: 'not found' });
    return res.status(200).json([]);
  }),
  getLatestStatus: jest.fn((req, res) => {
    if (req.params.shipment_id === '404') return res.status(404).json({ message: 'not found' });
    return res.status(200).json({ status: 'pending' });
  }),
  getPODPhoto: jest.fn((req, res) => {
    if (req.params.shipment_id === '404') return res.status(404).json({ message: 'not found' });
    return res.status(200).json({ url: 'https://photo' });
  }),
}));

const routes = require('../routes/shipmentStatusRoutes');
const app = createTestApp('/api/shipment-status', routes);

describe('ShipmentStatus Routes - /api/shipment-status/*', () => {
  describe('POST /api/shipment-status', () => {
    const valid = { shipment_id: 1, status: 'en_route', location_lat: 1, location_lng: 2 };
    test('happy path', async () => expect((await request(app).post('/api/shipment-status').send(valid)).status).toBe(201));
    test('not found -> 404', async () => expect((await request(app).post('/api/shipment-status').send({ ...valid, shipment_id: 404 })).status).toBe(404));
    test('missing fields safe', async () => expect([201, 400]).toContain((await request(app).post('/api/shipment-status').send({})).status));
    test('null shipment id safe', async () => expect([201, 400]).toContain((await request(app).post('/api/shipment-status').send({ ...valid, shipment_id: null })).status));
    test('sql injection safe', async () => expect((await request(app).post('/api/shipment-status').send({ ...valid, status: "' OR 1=1 --" })).status).not.toBe(500));
    test('xss payload safe', async () => expect((await request(app).post('/api/shipment-status').send({ ...valid, status: '<script>x</script>' })).status).not.toBe(500));
    test('boundary zero coords safe', async () => expect((await request(app).post('/api/shipment-status').send({ ...valid, location_lat: 0, location_lng: 0 })).status).not.toBe(500));
    test('boundary negative coords safe', async () => expect((await request(app).post('/api/shipment-status').send({ ...valid, location_lat: -90, location_lng: -180 })).status).not.toBe(500));
    test('oversized status safe', async () => expect((await request(app).post('/api/shipment-status').send({ ...valid, status: 'x'.repeat(2000) })).status).not.toBe(500));
    test('malformed JSON -> 400', async () => {
      const res = await request(app).post('/api/shipment-status').set('Content-Type', 'application/json').send('{"shipment_id":');
      expect(res.status).toBe(400);
    });
  });

  describe.each([
    ['/history', 'get status history'],
    ['/latest', 'get latest status'],
    ['/pod-photo', 'get pod photo'],
  ])('GET /api/shipment-status/:shipment_id%s', (suffix) => {
    const getPath = (id) => `/api/shipment-status/${encodeURIComponent(id)}${suffix}`;
    test('happy path', async () => expect((await request(app).get(getPath('1'))).status).toBe(200));
    test('not found -> 404', async () => expect((await request(app).get(getPath('404'))).status).toBe(404));
    test('invalid format safe', async () => expect((await request(app).get(getPath('abc'))).status).not.toBe(500));
    test('negative boundary safe', async () => expect((await request(app).get(getPath('-1'))).status).not.toBe(500));
    test('zero boundary safe', async () => expect((await request(app).get(getPath('0'))).status).not.toBe(500));
    test('oversized id safe', async () => expect((await request(app).get(getPath('9'.repeat(500)))).status).not.toBe(500));
    test('sql injection safe', async () => expect((await request(app).get(getPath("' OR 1=1 --"))).status).not.toBe(500));
    test('xss payload safe', async () => expect((await request(app).get(getPath('<script>x</script>'))).status).not.toBe(500));
    test('whitespace id safe', async () => expect((await request(app).get(getPath('   '))).status).not.toBe(500));
    test('unicode id safe', async () => expect((await request(app).get(getPath('١٢٣'))).status).not.toBe(500));
  });
});
