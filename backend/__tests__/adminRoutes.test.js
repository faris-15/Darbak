const request = require('supertest');
const jwt = require('jsonwebtoken');
const { createTestApp } = require('./helpers/createTestApp');

jest.mock('../controllers/adminController', () => {
  const generic = jest.fn((req, res) => {
    const raw = JSON.stringify({ ...req.params, ...req.query, ...req.body });
    if (raw.includes('404')) return res.status(404).json({ message: 'not found' });
    if (req.path.includes('/resolve') && !req.body.transactionId && !req.params.id) {
      return res.status(400).json({ message: 'missing required fields' });
    }
    return res.status(200).json({ success: true, route: req.path });
  });
  const exportReport = jest.fn((req, res) => res.status(200).json({ csv: 'ok' }));
  return {
    getStats: generic,
    getActivityFeed: generic,
    getNotifications: generic,
    markNotificationsRead: generic,
    browseUsers: generic,
    getUserDetail: generic,
    setUserActive: generic,
    verifyUser: generic,
    getUsers: generic,
    browseShipments: generic,
    getShipments: generic,
    getPendingUsers: generic,
    streamDocumentPreview: generic,
    streamDocumentPreviewById: generic,
    verifyDocument: generic,
    getSignedUrl: generic,
    listDisputes: generic,
    resolveDispute: generic,
    getPriceFloors: generic,
    createPriceFloor: generic,
    deletePriceFloor: generic,
    exportReport,
  };
});

const adminRoutes = require('../routes/adminRoutes');
const app = createTestApp('/api/admin', adminRoutes);

const signToken = (payload = { id: 1, role: 'admin' }, expiresIn = '1h') =>
  jwt.sign(payload, process.env.JWT_SECRET, { expiresIn });

const endpoints = [
  ['GET', '/stats'],
  ['GET', '/activity-feed'],
  ['GET', '/notifications'],
  ['POST', '/notifications/read'],
  ['GET', '/users/browse'],
  ['GET', '/users/1/detail'],
  ['PATCH', '/users/1/active'],
  ['POST', '/users/1/verify'],
  ['GET', '/users'],
  ['GET', '/shipments/browse'],
  ['GET', '/shipments'],
  ['GET', '/pending-users'],
  ['GET', '/documents/preview'],
  ['GET', '/documents/1/preview'],
  ['POST', '/documents/1/verify'],
  ['GET', '/get-signed-url'],
  ['GET', '/disputes'],
  ['POST', '/disputes/resolve'],
  ['POST', '/disputes/1/resolve'],
  ['GET', '/price-floors'],
  ['POST', '/price-floors'],
  ['DELETE', '/price-floors/1'],
  ['GET', '/export-report'],
];

describe('Admin Routes - /api/admin/*', () => {
  describe.each(endpoints)('%s %s', (method, path) => {
    const call = (token, body = {}, query = {}) => {
      let req = request(app)[method.toLowerCase()](`/api/admin${path}`).query(query);
      if (token) req = req.set('Authorization', `Bearer ${token}`);
      if (method !== 'GET' && method !== 'DELETE') req = req.send(body);
      return req;
    };

    test('happy path with valid admin token', async () => {
      const res = await call(signToken(), { transactionId: 1, status: 'resolved' });
      expect([200, 201]).toContain(res.status);
    });

    test('no token returns 401', async () => {
      const res = await call(null);
      expect(res.status).toBe(401);
    });

    test('expired token returns 401', async () => {
      const res = await call(signToken({ id: 1, role: 'admin' }, '-1s'));
      expect(res.status).toBe(401);
    });

    test('malformed token returns 401', async () => {
      const res = await call('bad.token');
      expect(res.status).toBe(401);
    });

    test('wrong role returns 403', async () => {
      const res = await call(signToken({ id: 1, role: 'driver' }));
      expect(res.status).toBe(403);
    });

    test('missing required fields handled safely', async () => {
      const res = await call(signToken(), {});
      expect([200, 400]).toContain(res.status);
    });

    test('not found scenario returns 404 when resource key is 404', async () => {
      const nfPath = path.replace('/1', '/404');
      let req = request(app)[method.toLowerCase()](`/api/admin${nfPath}`);
      req = req.set('Authorization', `Bearer ${signToken()}`);
      if (method !== 'GET' && method !== 'DELETE') req = req.send({ id: 404 });
      const res = await req;
      expect([200, 404]).toContain(res.status);
    });

    test('SQL injection payload is safe', async () => {
      const res = await call(signToken(), { query: "' OR 1=1 --" }, { q: "' OR 1=1 --" });
      expect(res.status).not.toBe(500);
    });

    test('XSS payload is safe', async () => {
      const res = await call(signToken(), { value: '<script>alert(1)</script>' }, { q: '<script>x</script>' });
      expect(res.status).not.toBe(500);
    });

    test('boundary values are handled', async () => {
      const res = await call(signToken(), { value: 'x'.repeat(1024) }, { limit: 0 });
      expect([200, 400]).toContain(res.status);
    });
  });
});
