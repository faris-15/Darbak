const request = require('supertest');
const { createTestApp } = require('./helpers/createTestApp');

jest.mock('../controllers/conversationController', () => ({
  postMessage: jest.fn((req, res) => {
    if (req.body.shipmentId === 404) return res.status(404).json({ message: 'not found' });
    return res.status(201).json({ success: true });
  }),
  getConversation: jest.fn((req, res) => {
    if (req.params.shipmentId === '404') return res.status(404).json({ message: 'not found' });
    return res.status(200).json([]);
  }),
}));

const routes = require('../routes/conversationRoutes');
const app = createTestApp('/api/conversations', routes);

describe('Conversation Routes - /api/conversations/*', () => {
  describe('POST /api/conversations', () => {
    const valid = { shipmentId: 1, senderId: 2, receiverId: 3, message: 'hello' };
    test('happy path', async () => expect((await request(app).post('/api/conversations').send(valid)).status).toBe(201));
    test('missing shipmentId -> 400', async () => expect((await request(app).post('/api/conversations').send({ ...valid, shipmentId: undefined })).status).toBe(400));
    test('missing senderId -> 400', async () => expect((await request(app).post('/api/conversations').send({ ...valid, senderId: undefined })).status).toBe(400));
    test('missing receiverId -> 400', async () => expect((await request(app).post('/api/conversations').send({ ...valid, receiverId: undefined })).status).toBe(400));
    test('missing message -> 400', async () => expect((await request(app).post('/api/conversations').send({ ...valid, message: '' })).status).toBe(400));
    test('not found -> 404', async () => expect((await request(app).post('/api/conversations').send({ ...valid, shipmentId: 404 })).status).toBe(404));
    test('sql injection safe', async () => expect((await request(app).post('/api/conversations').send({ ...valid, message: "' OR 1=1 --" })).status).not.toBe(500));
    test('xss safe', async () => expect((await request(app).post('/api/conversations').send({ ...valid, message: '<script>x</script>' })).status).not.toBe(500));
    test('boundary ids zero handled safely', async () => expect([201, 400]).toContain((await request(app).post('/api/conversations').send({ ...valid, shipmentId: 0 })).status));
    test('boundary oversized message safe', async () => expect((await request(app).post('/api/conversations').send({ ...valid, message: 'x'.repeat(4000) })).status).not.toBe(500));
  });

  describe('GET /api/conversations/shipment/:shipmentId', () => {
    test('happy path', async () => expect((await request(app).get('/api/conversations/shipment/1')).status).toBe(200));
    test('not found -> 404', async () => expect((await request(app).get('/api/conversations/shipment/404')).status).toBe(404));
    test('invalid id format safe', async () => expect((await request(app).get('/api/conversations/shipment/abc')).status).not.toBe(500));
    test('negative id safe', async () => expect((await request(app).get('/api/conversations/shipment/-1')).status).not.toBe(500));
    test('zero id boundary safe', async () => expect((await request(app).get('/api/conversations/shipment/0')).status).not.toBe(500));
    test('oversized id safe', async () => expect((await request(app).get(`/api/conversations/shipment/${'9'.repeat(300)}`)).status).not.toBe(500));
    test('sql injection safe', async () => expect((await request(app).get(`/api/conversations/shipment/${encodeURIComponent("' OR 1=1 --")}`)).status).not.toBe(500));
    test('xss safe', async () => expect((await request(app).get(`/api/conversations/shipment/${encodeURIComponent('<script>x</script>')}`)).status).not.toBe(500));
    test('whitespace id safe', async () => expect((await request(app).get(`/api/conversations/shipment/${encodeURIComponent('   ')}`)).status).not.toBe(500));
    test('unicode id safe', async () => expect((await request(app).get(`/api/conversations/shipment/${encodeURIComponent('١٢٣')}`)).status).not.toBe(500));
  });
});
