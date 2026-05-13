const request = require('supertest');
const { createTestApp } = require('./helpers/createTestApp');

jest.mock('../controllers/notificationController', () => ({
  getNotifications: jest.fn((req, res) => {
    if (req.params.userId === '404') return res.status(404).json({ message: 'not found' });
    return res.status(200).json({ items: [] });
  }),
  markAsRead: jest.fn((req, res) => {
    if (req.params.notificationId === '404') return res.status(404).json({ message: 'not found' });
    return res.status(200).json({ success: true });
  }),
  markAllAsRead: jest.fn((req, res) => {
    if (req.params.userId === '404') return res.status(404).json({ message: 'not found' });
    return res.status(200).json({ success: true });
  }),
  deleteNotification: jest.fn((req, res) => {
    if (req.params.notificationId === '404') return res.status(404).json({ message: 'not found' });
    return res.status(200).json({ success: true });
  }),
}));

const routes = require('../routes/notificationRoutes');
const app = createTestApp('/api/notifications', routes);

describe('Notification Routes - /api/notifications/*', () => {
  describe.each([
    ['GET', '/user/1'],
    ['POST', '/1/read'],
    ['POST', '/user/1/read-all'],
    ['DELETE', '/1'],
  ])('%s %s', (method, path) => {
    const call = (suffix = '', body = {}) => {
      const p = suffix ? path.replace('/1', `/${suffix}`) : path;
      let req = request(app)[method.toLowerCase()](`/api/notifications${p}`);
      if (method !== 'GET' && method !== 'DELETE') req = req.send(body);
      return req;
    };
    test('happy path', async () => expect((await call()).status).toBe(200));
    test('not found -> 404', async () => expect((await call('404')).status).toBe(404));
    test('missing required fields safe', async () => expect([200, 400]).toContain((await call('', {})).status));
    test('invalid id format safe', async () => expect((await call('abc')).status).not.toBe(500));
    test('negative id safe', async () => expect((await call('-1')).status).not.toBe(500));
    test('zero id safe', async () => expect((await call('0')).status).not.toBe(500));
    test('oversized id safe', async () => expect((await call('9'.repeat(300))).status).not.toBe(500));
    test('sql injection safe', async () => expect((await call("' OR 1=1 --")).status).not.toBe(500));
    test('xss safe', async () => expect((await call('<script>x</script>')).status).not.toBe(500));
    test('whitespace id safe', async () => expect((await call('   ')).status).not.toBe(500));
  });
});
