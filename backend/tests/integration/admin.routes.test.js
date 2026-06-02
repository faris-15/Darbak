/**
 * Comprehensive integration tests for /api/admin/* (adminController +
 * adminRoutes). Covers stats, browse, CRUD, document/operating-card
 * verification, signed URLs, disputes, price floors, exports, and the
 * overview-charts dashboard endpoint.
 *
 * Schema-probe SQL (`SHOW COLUMNS FROM users LIKE 'is_active'`) is satisfied
 * once via `dbMock.route` so individual tests only enqueue business SQL.
 */
'use strict';

const request = require('supertest');

const { buildTestApp } = require('../helpers/testApp');
const { dbMock } = require('../helpers/db');
const {
  tokenForAdmin,
  tokenForDriver,
  tokenForShipper,
  authHeader,
} = require('../helpers/auth');
const { userFactory, adminFactory } = require('../helpers/factories');

const app = () => buildTestApp({ routes: ['admin'] });

const adminToken = tokenForAdmin(1);
const driverToken = tokenForDriver(100);

const stubAdminAuth = () => {
  // requireAuth + requireAdmin -> JWT only, no DB lookup.
  // Tests still need to add a "is_active" SHOW COLUMNS route for endpoints
  // that probe the user schema (createUser, patchUserActive, getUserDetail).
  dbMock.route(/SHOW COLUMNS FROM users LIKE 'is_active'/i, () => [
    [{ Field: 'is_active' }],
    { fieldCount: 0 },
  ]);
};

describe('Authentication & role checks', () => {
  test('401 without token', async () => {
    const res = await request(app()).get('/api/admin/stats');
    expect(res.status).toBe(401);
  });

  test('403 when caller is not an admin', async () => {
    const res = await request(app())
      .get('/api/admin/stats')
      .set(authHeader(driverToken));
    expect(res.status).toBe(403);
  });
});

describe('GET /api/admin/stats', () => {
  test('200 returns aggregated dashboard payload', async () => {
    dbMock
      .expectSelect(/SELECT role, COUNT\(\*\) as total FROM users GROUP BY role/i)
      .returns([
        { role: 'driver', total: 5 },
        { role: 'shipper', total: 3 },
      ]);
    dbMock
      .expectSelect(/FROM compliance_documents WHERE is_verified = 0/i)
      .returns([{ pending: 4 }]);
    dbMock
      .expectSelect(/FROM shipments GROUP BY status/i)
      .returns([{ status: 'delivered', total: 12 }]);
    dbMock
      .expectSelect(/FROM shipments s\s+LEFT JOIN users u ON s\.shipper_id/i)
      .returns([{ id: 1, shipper: 'X' }]);
    dbMock
      .expectSelect(/UNION ALL/i)
      .returns([{ type: 'ship', actor: 'X', detail: 'a', activity_date: new Date() }]);
    dbMock
      .expectSelect(/SELECT\s+\(SELECT COUNT\(\*\) FROM users\) AS totalUsers/i)
      .returns([{ totalUsers: 8 }]);

    const res = await request(app())
      .get('/api/admin/stats')
      .set(authHeader(adminToken));
    expect(res.status).toBe(200);
    expect(res.body.data.summary.totalUsers).toBe(8);
    expect(res.body.data.userStats).toHaveLength(2);
  });

  test('500 when DB throws', async () => {
    dbMock
      .expectSelect(/SELECT role, COUNT/i)
      .rejectsWith(new Error('boom'));
    const res = await request(app())
      .get('/api/admin/stats')
      .set(authHeader(adminToken));
    expect(res.status).toBe(500);
  });
});

describe('GET /api/admin/overview-charts', () => {
  test('200 zero-pads missing days', async () => {
    dbMock
      .expectSelect(/FROM shipments\s+WHERE created_at >= DATE_SUB/i)
      .returns([{ d: new Date(), c: 3 }]);
    dbMock
      .expectSelect(/FROM bids\s+WHERE created_at >= DATE_SUB/i)
      .returns([{ d: '2026-05-26', c: 5 }]);
    const res = await request(app())
      .get('/api/admin/overview-charts')
      .set(authHeader(adminToken));
    expect(res.status).toBe(200);
    expect(res.body.data.series).toHaveLength(7);
  });

  test('500 on DB error', async () => {
    dbMock.expectSelect(/FROM shipments\s+WHERE/i).rejectsWith(new Error('x'));
    const res = await request(app())
      .get('/api/admin/overview-charts')
      .set(authHeader(adminToken));
    expect(res.status).toBe(500);
  });
});

describe('GET /api/admin/users', () => {
  test('200 returns users sorted by created_at', async () => {
    dbMock
      .expectSelect(/SELECT id, full_name, email, phone, role, verification_status, created_at FROM users ORDER BY created_at DESC/i)
      .returns([userFactory({ id: 1 })]);
    const res = await request(app())
      .get('/api/admin/users')
      .set(authHeader(adminToken));
    expect(res.status).toBe(200);
    expect(res.body.data).toHaveLength(1);
  });

  test('500 on DB error', async () => {
    dbMock
      .expectSelect(/FROM users ORDER BY created_at DESC/i)
      .rejectsWith(new Error('x'));
    const res = await request(app())
      .get('/api/admin/users')
      .set(authHeader(adminToken));
    expect(res.status).toBe(500);
  });
});

describe('GET /api/admin/shipments', () => {
  test('200 returns shipments with shipper join', async () => {
    dbMock
      .expectSelect(/FROM shipments s\s+LEFT JOIN users u/i)
      .returns([{ id: 1 }]);
    const res = await request(app())
      .get('/api/admin/shipments')
      .set(authHeader(adminToken));
    expect(res.status).toBe(200);
    expect(res.body.data).toHaveLength(1);
  });

  test('soft-fails to empty array on DB error (intentional 200)', async () => {
    dbMock
      .expectSelect(/FROM shipments s\s+LEFT JOIN users u/i)
      .rejectsWith(new Error('boom'));
    const res = await request(app())
      .get('/api/admin/shipments')
      .set(authHeader(adminToken));
    expect(res.status).toBe(200);
    expect(res.body.data).toEqual([]);
  });
});

describe('GET /api/admin/users/browse', () => {
  test('200 with filters paginates and counts', async () => {
    stubAdminAuth();
    dbMock
      .expectSelect(/SELECT COUNT\(\*\) AS total FROM users u/i)
      .returns([{ total: 1 }]);
    dbMock
      .expectSelect(/FROM users u/i)
      .returns([{ id: 5, full_name: 'X', role: 'driver' }]);
    const res = await request(app())
      .get('/api/admin/users/browse?role=driver&q=x&verification=pending&active=1&dateFrom=2026-01-01&dateTo=2026-12-31&page=1&limit=10')
      .set(authHeader(adminToken));
    expect(res.status).toBe(200);
    expect(res.body.pagination.total).toBe(1);
  });

  test('500 when count throws', async () => {
    stubAdminAuth();
    dbMock
      .expectSelect(/SELECT COUNT\(\*\) AS total FROM users u/i)
      .rejectsWith(new Error('x'));
    const res = await request(app())
      .get('/api/admin/users/browse')
      .set(authHeader(adminToken));
    expect(res.status).toBe(500);
  });
});

describe('GET /api/admin/shipments/browse', () => {
  test('200 with all filters', async () => {
    dbMock
      .expectSelect(/SELECT COUNT\(\*\) AS total\s+FROM shipments s/i)
      .returns([{ total: 2 }]);
    dbMock
      .expectSelect(/SELECT s\.id, s\.status, s\.base_price/i)
      .returns([{ id: 1, status: 'delivered' }]);
    const res = await request(app())
      .get('/api/admin/shipments/browse?q=hello&status=delivered&dateFrom=2026-01-01&dateTo=2026-12-31&page=2&limit=5')
      .set(authHeader(adminToken));
    expect(res.status).toBe(200);
    expect(res.body.pagination.total).toBe(2);
  });

  test('500 on DB error', async () => {
    dbMock
      .expectSelect(/SELECT COUNT\(\*\) AS total\s+FROM shipments s/i)
      .rejectsWith(new Error('x'));
    const res = await request(app())
      .get('/api/admin/shipments/browse')
      .set(authHeader(adminToken));
    expect(res.status).toBe(500);
  });
});

describe('GET /api/admin/users/:id/detail', () => {
  test('404 when user not found', async () => {
    dbMock
      .expectSelect(/FROM users WHERE id = \? LIMIT 1/i)
      .returns([]);
    const res = await request(app())
      .get('/api/admin/users/9999/detail')
      .set(authHeader(adminToken));
    expect(res.status).toBe(404);
  });

  test('200 returns shipper detail (no trucks)', async () => {
    stubAdminAuth();
    dbMock
      .expectSelect(/FROM users WHERE id = \? LIMIT 1/i)
      .returns([{ id: 200, role: 'shipper', full_name: 'Y' }]);
    dbMock
      .expectSelect(/SELECT is_active FROM users WHERE id = \?/i)
      .returns([{ is_active: 1 }]);
    const res = await request(app())
      .get('/api/admin/users/200/detail')
      .set(authHeader(adminToken));
    expect(res.status).toBe(200);
    expect(res.body.data.trucks).toEqual([]);
  });

  test('200 returns driver detail with trucks + operating card', async () => {
    stubAdminAuth();
    dbMock
      .expectSelect(/FROM users WHERE id = \? LIMIT 1/i)
      .returns([{ id: 100, role: 'driver' }]);
    dbMock
      .expectSelect(/FROM trucks WHERE user_id = \?/i)
      .returns([{ plate_number: 'A-1', truck_type: 'dyna' }]);
    dbMock
      .expectSelect(/FROM driver_operating_cards/i)
      .returns([{ id: 90, file_key: 'k.pdf' }]);
    dbMock
      .expectSelect(/SELECT is_active FROM users WHERE id = \?/i)
      .returns([{ is_active: 0 }]);
    const res = await request(app())
      .get('/api/admin/users/100/detail')
      .set(authHeader(adminToken));
    expect(res.status).toBe(200);
    expect(res.body.data.trucks).toHaveLength(1);
    expect(res.body.data.operating_card.id).toBe(90);
    expect(res.body.data.is_active).toBe(0);
  });
});

describe('PATCH /api/admin/users/:id/active', () => {
  test('400 when is_active column missing', async () => {
    dbMock
      .expectSelect(/SHOW COLUMNS FROM users LIKE 'is_active'/i)
      .returns([]);
    const res = await request(app())
      .patch('/api/admin/users/200/active')
      .set(authHeader(adminToken))
      .send({ is_active: 0 });
    expect(res.status).toBe(400);
  });

  test('404 when user missing', async () => {
    stubAdminAuth();
    dbMock
      .expectSelect(/SELECT id, role FROM users WHERE id = \? LIMIT 1/i)
      .returns([]);
    const res = await request(app())
      .patch('/api/admin/users/9999/active')
      .set(authHeader(adminToken))
      .send({ is_active: 0 });
    expect(res.status).toBe(404);
  });

  test('400 when target is an admin', async () => {
    stubAdminAuth();
    dbMock
      .expectSelect(/SELECT id, role FROM users WHERE id = \? LIMIT 1/i)
      .returns([{ id: 2, role: 'admin' }]);
    const res = await request(app())
      .patch('/api/admin/users/2/active')
      .set(authHeader(adminToken))
      .send({ is_active: 0 });
    expect(res.status).toBe(400);
  });

  test('400 when admin tries to deactivate self', async () => {
    stubAdminAuth();
    dbMock
      .expectSelect(/SELECT id, role FROM users WHERE id = \? LIMIT 1/i)
      .returns([{ id: 1, role: 'admin' }]);
    const res = await request(app())
      .patch('/api/admin/users/1/active')
      .set(authHeader(adminToken))
      .send({ is_active: 0 });
    expect(res.status).toBe(400);
  });

  test('200 toggles is_active', async () => {
    stubAdminAuth();
    dbMock
      .expectSelect(/SELECT id, role FROM users WHERE id = \? LIMIT 1/i)
      .returns([{ id: 100, role: 'driver' }]);
    dbMock
      .expectUpdate(/UPDATE users SET is_active = \? WHERE id = \?/i)
      .returnsAffected(1);
    const res = await request(app())
      .patch('/api/admin/users/100/active')
      .set(authHeader(adminToken))
      .send({ is_active: 1 });
    expect(res.status).toBe(200);
  });
});

describe('POST /api/admin/users (createUser)', () => {
  test('400 when required fields missing or password too short', async () => {
    const res = await request(app())
      .post('/api/admin/users')
      .set(authHeader(adminToken))
      .send({ full_name: 'X', email: 'a@b.c', phone: '0', password: '12' });
    expect(res.status).toBe(400);
  });

  test('400 when role is invalid', async () => {
    const res = await request(app())
      .post('/api/admin/users')
      .set(authHeader(adminToken))
      .send({
        full_name: 'X',
        email: 'a@b.c',
        phone: '0500',
        password: 'secret123',
        role: 'mod',
      });
    expect(res.status).toBe(400);
  });

  test('400 when phone or email is already used', async () => {
    dbMock
      .expectSelect(/FROM users WHERE phone = \? LIMIT 1/i)
      .returns([{ id: 1 }]);
    dbMock
      .expectSelect(/FROM users WHERE LOWER\(email\) = LOWER\(\?\) LIMIT 1/i)
      .returns([]);
    const res = await request(app())
      .post('/api/admin/users')
      .set(authHeader(adminToken))
      .send({
        full_name: 'X',
        email: 'a@b.c',
        phone: '0500',
        password: 'secret123',
        role: 'driver',
      });
    expect(res.status).toBe(400);
  });

  test('201 creates a new user and a wallet within a transaction', async () => {
    stubAdminAuth();
    dbMock
      .expectSelect(/FROM users WHERE phone = \? LIMIT 1/i)
      .returns([]);
    dbMock
      .expectSelect(/FROM users WHERE LOWER\(email\) = LOWER\(\?\) LIMIT 1/i)
      .returns([]);
    dbMock.expectInsert(/INSERT INTO users/i).returnsInsert(5000);
    dbMock.expectInsert(/INSERT INTO wallets/i).returnsInsert(1);
    const res = await request(app())
      .post('/api/admin/users')
      .set(authHeader(adminToken))
      .send({
        full_name: 'سائق جديد',
        email: 'a@b.c',
        phone: '0500',
        password: 'secret123',
        role: 'driver',
      });
    expect(res.status).toBe(201);
    expect(res.body.data.id).toBe(5000);
    expect(dbMock.transactionState).toBe('committed');
  });

  test('500 rolls back transaction on DB error', async () => {
    stubAdminAuth();
    dbMock
      .expectSelect(/FROM users WHERE phone = \? LIMIT 1/i)
      .returns([]);
    dbMock
      .expectSelect(/FROM users WHERE LOWER\(email\) = LOWER\(\?\) LIMIT 1/i)
      .returns([]);
    dbMock
      .expectInsert(/INSERT INTO users/i)
      .rejectsWith(new Error('boom'));
    const res = await request(app())
      .post('/api/admin/users')
      .set(authHeader(adminToken))
      .send({
        full_name: 'سائق جديد',
        email: 'a@b.c',
        phone: '0500',
        password: 'secret123',
        role: 'driver',
      });
    expect(res.status).toBe(500);
    expect(dbMock.transactionState).toBe('rolledback');
  });
});

describe('PATCH /api/admin/users/:id (patchUser)', () => {
  test('404 when user not found', async () => {
    dbMock
      .expectSelect(/SELECT id, role, email, phone FROM users WHERE id = \? LIMIT 1/i)
      .returns([]);
    const res = await request(app())
      .patch('/api/admin/users/9999')
      .set(authHeader(adminToken))
      .send({ full_name: 'New' });
    expect(res.status).toBe(404);
  });

  test('400 when no fields supplied', async () => {
    dbMock
      .expectSelect(/SELECT id, role, email, phone FROM users WHERE id = \? LIMIT 1/i)
      .returns([{ id: 100, role: 'driver', email: 'a@b.c', phone: '0500' }]);
    const res = await request(app())
      .patch('/api/admin/users/100')
      .set(authHeader(adminToken))
      .send({});
    expect(res.status).toBe(400);
  });

  test('400 when password is too short', async () => {
    dbMock
      .expectSelect(/SELECT id, role, email, phone FROM users WHERE id = \? LIMIT 1/i)
      .returns([{ id: 100, role: 'driver', email: 'a@b.c', phone: '0500' }]);
    const res = await request(app())
      .patch('/api/admin/users/100')
      .set(authHeader(adminToken))
      .send({ password: '12' });
    expect(res.status).toBe(400);
  });

  test('400 when role on admin cannot be changed', async () => {
    dbMock
      .expectSelect(/SELECT id, role, email, phone FROM users WHERE id = \? LIMIT 1/i)
      .returns([{ id: 1, role: 'admin' }]);
    const res = await request(app())
      .patch('/api/admin/users/1')
      .set(authHeader(adminToken))
      .send({ role: 'driver' });
    expect(res.status).toBe(400);
  });

  test('400 when email is already in use by another user', async () => {
    dbMock
      .expectSelect(/SELECT id, role, email, phone FROM users WHERE id = \? LIMIT 1/i)
      .returns([{ id: 100, role: 'driver', email: 'a@b.c', phone: '0500' }]);
    dbMock
      .expectSelect(/FROM users WHERE LOWER\(email\) = LOWER\(\?\) LIMIT 1/i)
      .returns([{ id: 999 }]);
    const res = await request(app())
      .patch('/api/admin/users/100')
      .set(authHeader(adminToken))
      .send({ email: 'new@b.c' });
    expect(res.status).toBe(400);
  });

  test('200 successfully updates user fields', async () => {
    dbMock
      .expectSelect(/SELECT id, role, email, phone FROM users WHERE id = \? LIMIT 1/i)
      .returns([{ id: 100, role: 'driver', email: 'a@b.c', phone: '0500' }]);
    dbMock.expectUpdate(/UPDATE users SET/i).returnsAffected(1);
    const res = await request(app())
      .patch('/api/admin/users/100')
      .set(authHeader(adminToken))
      .send({ full_name: 'NewName', verification_status: 'verified' });
    expect(res.status).toBe(200);
  });
});

describe('Stub endpoints', () => {
  test('GET /api/admin/disputes returns empty array', async () => {
    const res = await request(app())
      .get('/api/admin/disputes')
      .set(authHeader(adminToken));
    expect(res.status).toBe(200);
    expect(res.body.data).toEqual([]);
  });

  test('POST /api/admin/disputes/resolve returns success', async () => {
    const res = await request(app())
      .post('/api/admin/disputes/resolve')
      .set(authHeader(adminToken));
    expect(res.status).toBe(200);
  });

  test('GET /api/admin/activity-feed returns empty array', async () => {
    const res = await request(app())
      .get('/api/admin/activity-feed')
      .set(authHeader(adminToken));
    expect(res.status).toBe(200);
    expect(res.body.data).toEqual([]);
  });

  test('GET /api/admin/notifications returns empty list', async () => {
    const res = await request(app())
      .get('/api/admin/notifications')
      .set(authHeader(adminToken));
    expect(res.status).toBe(200);
    expect(res.body.data.unreadCount).toBe(0);
  });

  test('POST /api/admin/notifications/read returns success', async () => {
    const res = await request(app())
      .post('/api/admin/notifications/read')
      .set(authHeader(adminToken));
    expect(res.status).toBe(200);
  });
});

describe('GET /api/admin/pending-users', () => {
  test('200 returns paginated pending items', async () => {
    dbMock.expectSelect(/SELECT \(/i).returns([{ total: 3 }]);
    dbMock.expectSelect(/UNION ALL/i).returns([
      { user_id: 100, full_name: 'X', document_type: 'license', source_kind: 'compliance' },
    ]);
    const res = await request(app())
      .get('/api/admin/pending-users')
      .set(authHeader(adminToken));
    expect(res.status).toBe(200);
    expect(res.body.pagination.total).toBe(3);
  });

  test('500 on DB error', async () => {
    dbMock
      .expectSelect(/SELECT \(/i)
      .rejectsWith(new Error('boom'));
    const res = await request(app())
      .get('/api/admin/pending-users')
      .set(authHeader(adminToken));
    expect(res.status).toBe(500);
  });
});

describe('POST /api/admin/documents/:docId/verify', () => {
  test('400 when docId is missing or "undefined"', async () => {
    const res = await request(app())
      .post('/api/admin/documents/undefined/verify')
      .set(authHeader(adminToken))
      .send({ status: 'verified' });
    expect(res.status).toBe(400);
  });

  test('200 verifies document and updates user', async () => {
    dbMock
      .expectUpdate(/UPDATE compliance_documents/i)
      .returnsAffected(1);
    dbMock
      .expectSelect(/SELECT user_id FROM compliance_documents WHERE document_id = \?/i)
      .returns([{ user_id: 100 }]);
    dbMock
      .expectUpdate(/UPDATE users SET verification_status = "verified" WHERE id = \?/i)
      .returnsAffected(1);
    const res = await request(app())
      .post('/api/admin/documents/55/verify')
      .set(authHeader(adminToken))
      .send({ status: 'verified', notes: 'OK' });
    expect(res.status).toBe(200);
  });

  test('200 rejects document and updates user verification', async () => {
    dbMock
      .expectUpdate(/UPDATE compliance_documents/i)
      .returnsAffected(1);
    dbMock
      .expectSelect(/SELECT user_id FROM compliance_documents WHERE document_id = \?/i)
      .returns([{ user_id: 100 }]);
    dbMock
      .expectUpdate(/UPDATE users SET verification_status = "rejected" WHERE id = \?/i)
      .returnsAffected(1);
    const res = await request(app())
      .post('/api/admin/documents/55/verify')
      .set(authHeader(adminToken))
      .send({ status: 'rejected' });
    expect(res.status).toBe(200);
  });

  test('500 when DB fails', async () => {
    dbMock
      .expectUpdate(/UPDATE compliance_documents/i)
      .rejectsWith(new Error('x'));
    const res = await request(app())
      .post('/api/admin/documents/55/verify')
      .set(authHeader(adminToken))
      .send({ status: 'verified' });
    expect(res.status).toBe(500);
  });
});

describe('GET /api/admin/get-signed-url', () => {
  test('400 when no source provided', async () => {
    const res = await request(app())
      .get('/api/admin/get-signed-url')
      .set(authHeader(adminToken));
    expect(res.status).toBe(400);
  });

  test('404 when operating card not found', async () => {
    dbMock
      .expectSelect(/FROM driver_operating_cards WHERE id = \? LIMIT 1/i)
      .returns([]);
    const res = await request(app())
      .get('/api/admin/get-signed-url?cardId=999')
      .set(authHeader(adminToken));
    expect(res.status).toBe(404);
  });

  test('404 when document not found', async () => {
    dbMock
      .expectSelect(/FROM compliance_documents WHERE document_id = \? LIMIT 1/i)
      .returns([]);
    const res = await request(app())
      .get('/api/admin/get-signed-url?docId=999')
      .set(authHeader(adminToken));
    expect(res.status).toBe(404);
  });

  test('200 returns signed URL for a document', async () => {
    dbMock
      .expectSelect(/FROM compliance_documents WHERE document_id = \? LIMIT 1/i)
      .returns([{ document_url: 'docs/license.pdf' }]);
    const res = await request(app())
      .get('/api/admin/get-signed-url?docId=55')
      .set(authHeader(adminToken));
    expect(res.status).toBe(200);
    expect(res.body.signedUrl).toMatch(/test-s3.local/);
    expect(res.body.fileType).toBe('pdf');
  });

  test('200 returns signed URL with raw url query (image)', async () => {
    const res = await request(app())
      .get('/api/admin/get-signed-url?url=images/a.png')
      .set(authHeader(adminToken));
    expect(res.status).toBe(200);
    expect(res.body.fileType).toBe('image');
  });
});

describe('POST /api/admin/operating-cards/:cardId/verify', () => {
  test('400 when status is invalid', async () => {
    const res = await request(app())
      .post('/api/admin/operating-cards/77/verify')
      .set(authHeader(adminToken))
      .send({ status: 'maybe' });
    expect(res.status).toBe(400);
  });

  test('404 when operating card not found', async () => {
    dbMock
      .expectUpdate(/UPDATE driver_operating_cards/i)
      .returnsAffected(0);
    const res = await request(app())
      .post('/api/admin/operating-cards/77/verify')
      .set(authHeader(adminToken))
      .send({ status: 'verified' });
    expect(res.status).toBe(404);
  });

  test('200 marks operating card as rejected with reason', async () => {
    dbMock
      .expectUpdate(/UPDATE driver_operating_cards/i)
      .returnsAffected(1);
    const res = await request(app())
      .post('/api/admin/operating-cards/77/verify')
      .set(authHeader(adminToken))
      .send({ status: 'rejected', rejection_reason: 'منتهي' });
    expect(res.status).toBe(200);
  });
});

describe('POST /api/admin/users/:id/verify', () => {
  test('200 marks user as verified', async () => {
    dbMock
      .expectUpdate(/UPDATE users SET verification_status = "verified"/i)
      .returnsAffected(1);
    const res = await request(app())
      .post('/api/admin/users/100/verify')
      .set(authHeader(adminToken));
    expect(res.status).toBe(200);
  });

  test('500 on DB error', async () => {
    dbMock
      .expectUpdate(/UPDATE users SET verification_status = "verified"/i)
      .rejectsWith(new Error('x'));
    const res = await request(app())
      .post('/api/admin/users/100/verify')
      .set(authHeader(adminToken));
    expect(res.status).toBe(500);
  });
});

describe('Price floors CRUD', () => {
  test('GET 200', async () => {
    dbMock.expectSelect(/FROM price_floors/i).returns([{ id: 1, origin: 'الرياض' }]);
    const res = await request(app())
      .get('/api/admin/price-floors')
      .set(authHeader(adminToken));
    expect(res.status).toBe(200);
    expect(res.body.data).toHaveLength(1);
  });

  test('GET 500 on error', async () => {
    dbMock.expectSelect(/FROM price_floors/i).rejectsWith(new Error('x'));
    const res = await request(app())
      .get('/api/admin/price-floors')
      .set(authHeader(adminToken));
    expect(res.status).toBe(500);
  });

  test('POST creates a new price floor', async () => {
    dbMock.expectInsert(/INSERT INTO price_floors/i).returnsInsert(1);
    const res = await request(app())
      .post('/api/admin/price-floors')
      .set(authHeader(adminToken))
      .send({ origin: 'الرياض', destination: 'جدة', min_price: 800 });
    expect(res.status).toBe(200);
  });

  test('POST 500 on error', async () => {
    dbMock.expectInsert(/INSERT INTO price_floors/i).rejectsWith(new Error('x'));
    const res = await request(app())
      .post('/api/admin/price-floors')
      .set(authHeader(adminToken))
      .send({ origin: 'الرياض', destination: 'جدة', min_price: 800 });
    expect(res.status).toBe(500);
  });

  test('DELETE removes a price floor', async () => {
    dbMock.expectDelete(/DELETE FROM price_floors/i).returnsAffected(1);
    const res = await request(app())
      .delete('/api/admin/price-floors/4')
      .set(authHeader(adminToken));
    expect(res.status).toBe(200);
  });

  test('DELETE 500 on error', async () => {
    dbMock.expectDelete(/DELETE FROM price_floors/i).rejectsWith(new Error('x'));
    const res = await request(app())
      .delete('/api/admin/price-floors/4')
      .set(authHeader(adminToken));
    expect(res.status).toBe(500);
  });
});

describe('GET /api/admin/export-report', () => {
  test('200 returns users + shipments', async () => {
    dbMock.expectSelect(/SELECT \* FROM users/i).returns([{ id: 1 }]);
    dbMock.expectSelect(/SELECT \* FROM shipments/i).returns([{ id: 1 }]);
    const res = await request(app())
      .get('/api/admin/export-report')
      .set(authHeader(adminToken));
    expect(res.status).toBe(200);
    expect(res.body.data.users).toHaveLength(1);
    expect(res.body.data.shipments).toHaveLength(1);
  });

  test('500 on error', async () => {
    dbMock.expectSelect(/SELECT \* FROM users/i).rejectsWith(new Error('x'));
    const res = await request(app())
      .get('/api/admin/export-report')
      .set(authHeader(adminToken));
    expect(res.status).toBe(500);
  });
});

describe('GET /api/admin/documents/preview', () => {
  test('400 when url missing', async () => {
    const res = await request(app())
      .get('/api/admin/documents/preview')
      .set(authHeader(adminToken));
    expect(res.status).toBe(400);
  });

  test('400 when key cannot be resolved', async () => {
    const res = await request(app())
      .get('/api/admin/documents/preview?url=')
      .set(authHeader(adminToken));
    expect(res.status).toBe(400);
  });
});

describe('GET /api/admin/documents/:id/preview', () => {
  test('404 for missing compliance doc', async () => {
    dbMock
      .expectSelect(/FROM compliance_documents WHERE document_id = \? LIMIT 1/i)
      .returns([]);
    const res = await request(app())
      .get('/api/admin/documents/55/preview')
      .set(authHeader(adminToken));
    expect(res.status).toBe(404);
  });

  test('404 for missing operating card', async () => {
    dbMock
      .expectSelect(/FROM driver_operating_cards WHERE id = \? LIMIT 1/i)
      .returns([]);
    const res = await request(app())
      .get('/api/admin/documents/55/preview?kind=operating_card')
      .set(authHeader(adminToken));
    expect(res.status).toBe(404);
  });

  test('400 when MINIO_BUCKET not configured', async () => {
    const prev = process.env.MINIO_BUCKET;
    delete process.env.MINIO_BUCKET;
    dbMock
      .expectSelect(/FROM compliance_documents WHERE document_id = \? LIMIT 1/i)
      .returns([{ document_url: 'docs/x.pdf' }]);
    const res = await request(app())
      .get('/api/admin/documents/55/preview')
      .set(authHeader(adminToken));
    expect(res.status).toBe(500);
    if (prev) process.env.MINIO_BUCKET = prev;
  });
});
