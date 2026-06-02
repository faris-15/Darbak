/**
 * Extra coverage for adminController error paths and edge branches that
 * aren't exercised by the main admin.routes.test.js suite:
 *
 *   - getUserDetail / patchUserActive / patchUser catch blocks
 *   - createUser without an `is_active` column
 *   - patchUser full validation matrix + admin-protection branches
 *   - getSignedUrl variants (cardId path, invalid signed URL, catch)
 *   - previewDocumentById (operating_card path, invalid key, S3 streaming)
 *   - previewDocumentByQuery (happy path, catch)
 *   - verifyOperatingCard (missing cardId, throw)
 *   - overviewCharts string-date branch
 */
'use strict';

const { Readable } = require('stream');
const request = require('supertest');

const { buildTestApp } = require('../helpers/testApp');
const { dbMock } = require('../helpers/db');
const { tokenForAdmin, authHeader } = require('../helpers/auth');
const s3Mock = require('../helpers/s3Mock');

const app = () => buildTestApp({ routes: ['admin'] });
const adminToken = tokenForAdmin(1);

const stubIsActiveCol = () => {
  dbMock.route(/SHOW COLUMNS FROM users LIKE 'is_active'/i, () => [
    [{ Field: 'is_active' }],
    { fieldCount: 0 },
  ]);
};

describe('Admin controller — additional error and branch coverage', () => {
  beforeEach(() => {
    if (!process.env.MINIO_BUCKET) process.env.MINIO_BUCKET = 'darbak-tests';
    // `mockImplementationOnce` does NOT auto-flush between tests — without
    // an explicit reset here a queued S3 mock would leak into the next test.
    s3Mock.s3.send.mockReset().mockResolvedValue({});
    s3Mock.generatePresignedUrl
      .mockReset()
      .mockImplementation(async (key) => {
        if (!key) return null;
        return `https://test-s3.local/presigned/${encodeURIComponent(key)}?sig=test`;
      });
    s3Mock.resolveS3ObjectKey.mockReset().mockImplementation((k) => k);
  });

  describe('getUserDetail catch path', () => {
    test('500 when initial users SELECT throws', async () => {
      dbMock
        .expectSelect(/FROM users WHERE id = \? LIMIT 1/i)
        .rejectsWith(new Error('db down'));
      const res = await request(app())
        .get('/api/admin/users/100/detail')
        .set(authHeader(adminToken));
      expect(res.status).toBe(500);
    });
  });

  describe('patchUserActive catch path', () => {
    test('500 when SHOW COLUMNS probe throws', async () => {
      dbMock
        .expectSelect(/SHOW COLUMNS FROM users LIKE 'is_active'/i)
        .rejectsWith(new Error('db down'));
      const res = await request(app())
        .patch('/api/admin/users/200/active')
        .set(authHeader(adminToken))
        .send({ is_active: 0 });
      expect(res.status).toBe(500);
    });
  });

  describe('createUser without is_active column', () => {
    test('201 falls back to INSERT without is_active', async () => {
      // Controller order: existsByPhone + existsByEmail (Promise.all),
      // then SHOW COLUMNS (in try/catch), then INSERT users, INSERT wallets.
      dbMock
        .expectSelect(/FROM users WHERE phone = \? LIMIT 1/i)
        .returns([]);
      dbMock
        .expectSelect(/FROM users WHERE LOWER\(email\) = LOWER\(\?\) LIMIT 1/i)
        .returns([]);
      dbMock
        .expectSelect(/SHOW COLUMNS FROM users LIKE 'is_active'/i)
        .returns([]);
      dbMock.expectInsert(/INSERT INTO users \(/i).returnsInsert(5001);
      dbMock.expectInsert(/INSERT INTO wallets/i).returnsInsert(1);
      const res = await request(app())
        .post('/api/admin/users')
        .set(authHeader(adminToken))
        .send({
          full_name: 'سائق جديد',
          email: 'no-active@b.c',
          phone: '0501',
          password: 'secret123',
          role: 'driver',
        });
      expect(res.status).toBe(201);
      expect(res.body.data.id).toBe(5001);
    });
  });

  describe('patchUser additional validation branches', () => {
    const existingDriver = () => ({
      id: 100,
      role: 'driver',
      email: 'a@b.c',
      phone: '0500',
    });

    test('400 when full_name set to empty string', async () => {
      dbMock
        .expectSelect(/SELECT id, role, email, phone FROM users WHERE id = \? LIMIT 1/i)
        .returns([existingDriver()]);
      const res = await request(app())
        .patch('/api/admin/users/100')
        .set(authHeader(adminToken))
        .send({ full_name: '   ' });
      expect(res.status).toBe(400);
    });

    test('400 when email set to empty string', async () => {
      dbMock
        .expectSelect(/SELECT id, role, email, phone FROM users WHERE id = \? LIMIT 1/i)
        .returns([existingDriver()]);
      const res = await request(app())
        .patch('/api/admin/users/100')
        .set(authHeader(adminToken))
        .send({ email: '   ' });
      expect(res.status).toBe(400);
    });

    test('400 when phone set to empty string', async () => {
      dbMock
        .expectSelect(/SELECT id, role, email, phone FROM users WHERE id = \? LIMIT 1/i)
        .returns([existingDriver()]);
      const res = await request(app())
        .patch('/api/admin/users/100')
        .set(authHeader(adminToken))
        .send({ phone: '   ' });
      expect(res.status).toBe(400);
    });

    test('400 when invalid role supplied', async () => {
      dbMock
        .expectSelect(/SELECT id, role, email, phone FROM users WHERE id = \? LIMIT 1/i)
        .returns([existingDriver()]);
      const res = await request(app())
        .patch('/api/admin/users/100')
        .set(authHeader(adminToken))
        .send({ role: 'mod' });
      expect(res.status).toBe(400);
    });

    test('400 when invalid verification_status', async () => {
      dbMock
        .expectSelect(/SELECT id, role, email, phone FROM users WHERE id = \? LIMIT 1/i)
        .returns([existingDriver()]);
      const res = await request(app())
        .patch('/api/admin/users/100')
        .set(authHeader(adminToken))
        .send({ verification_status: 'pendingish' });
      expect(res.status).toBe(400);
    });

    test('400 when changing verification_status on an admin', async () => {
      dbMock
        .expectSelect(/SELECT id, role, email, phone FROM users WHERE id = \? LIMIT 1/i)
        .returns([{ id: 1, role: 'admin', email: 'admin@b.c', phone: '0' }]);
      const res = await request(app())
        .patch('/api/admin/users/1')
        .set(authHeader(adminToken))
        .send({ verification_status: 'verified' });
      expect(res.status).toBe(400);
    });

    test('400 when promoting non-admin to admin', async () => {
      dbMock
        .expectSelect(/SELECT id, role, email, phone FROM users WHERE id = \? LIMIT 1/i)
        .returns([existingDriver()]);
      const res = await request(app())
        .patch('/api/admin/users/100')
        .set(authHeader(adminToken))
        .send({ role: 'admin' });
      expect(res.status).toBe(400);
    });

    test('400 when phone is already in use by another user', async () => {
      dbMock
        .expectSelect(/SELECT id, role, email, phone FROM users WHERE id = \? LIMIT 1/i)
        .returns([existingDriver()]);
      dbMock
        .expectSelect(/FROM users WHERE phone = \? LIMIT 1/i)
        .returns([{ id: 999 }]);
      const res = await request(app())
        .patch('/api/admin/users/100')
        .set(authHeader(adminToken))
        .send({ phone: '0502' });
      expect(res.status).toBe(400);
    });

    test('200 updates phone + role + password in one call', async () => {
      dbMock
        .expectSelect(/SELECT id, role, email, phone FROM users WHERE id = \? LIMIT 1/i)
        .returns([existingDriver()]);
      dbMock
        .expectSelect(/FROM users WHERE phone = \? LIMIT 1/i)
        .returns([]);
      dbMock.expectUpdate(/UPDATE users SET/i).returnsAffected(1);
      const res = await request(app())
        .patch('/api/admin/users/100')
        .set(authHeader(adminToken))
        .send({ phone: '0502', role: 'shipper', password: 'newpass123' });
      expect(res.status).toBe(200);
    });

    test('500 when UPDATE throws', async () => {
      dbMock
        .expectSelect(/SELECT id, role, email, phone FROM users WHERE id = \? LIMIT 1/i)
        .returns([existingDriver()]);
      dbMock
        .expectUpdate(/UPDATE users SET/i)
        .rejectsWith(new Error('db down'));
      const res = await request(app())
        .patch('/api/admin/users/100')
        .set(authHeader(adminToken))
        .send({ full_name: 'New' });
      expect(res.status).toBe(500);
    });
  });

  describe('getSignedUrl additional branches', () => {
    test('200 resolves operating-card file_key for signing', async () => {
      dbMock
        .expectSelect(/FROM driver_operating_cards WHERE id = \? LIMIT 1/i)
        .returns([{ file_key: 'cards/77.pdf', file_url: null }]);
      const res = await request(app())
        .get('/api/admin/get-signed-url?cardId=77')
        .set(authHeader(adminToken));
      expect(res.status).toBe(200);
      expect(res.body.signedUrl).toMatch(/test-s3.local/);
      expect(res.body.fileType).toBe('pdf');
    });

    test('502 when presigner returns a non-URL', async () => {
      s3Mock.generatePresignedUrl.mockImplementationOnce(async () => null);
      const res = await request(app())
        .get('/api/admin/get-signed-url?url=keys/x.pdf')
        .set(authHeader(adminToken));
      expect(res.status).toBe(502);
    });

    test('500 when presigner throws', async () => {
      s3Mock.generatePresignedUrl.mockImplementationOnce(async () => {
        throw new Error('s3 down');
      });
      const res = await request(app())
        .get('/api/admin/get-signed-url?url=keys/x.pdf')
        .set(authHeader(adminToken));
      expect(res.status).toBe(500);
    });
  });

  describe('previewDocumentById — operating_card and stream', () => {
    test('400 when resolveS3ObjectKey returns empty', async () => {
      s3Mock.resolveS3ObjectKey.mockImplementation(() => '');
      dbMock
        .expectSelect(/FROM compliance_documents WHERE document_id = \? LIMIT 1/i)
        .returns([{ document_url: 'docs/x.pdf' }]);
      const res = await request(app())
        .get('/api/admin/documents/55/preview')
        .set(authHeader(adminToken));
      expect(res.status).toBe(400);
    });

    test('200 streams a compliance document via S3 Body (pipe path)', async () => {
      dbMock
        .expectSelect(/FROM compliance_documents WHERE document_id = \? LIMIT 1/i)
        .returns([{ document_url: 'docs/x.pdf' }]);
      const fakeBody = Readable.from([Buffer.from('hello pdf')]);
      s3Mock.s3.send.mockImplementationOnce(async () => ({
        Body: fakeBody,
        ContentType: 'application/pdf',
        ContentLength: 9,
      }));
      const res = await request(app())
        .get('/api/admin/documents/55/preview')
        .set(authHeader(adminToken))
        .buffer(true);
      expect(res.status).toBe(200);
      expect(res.headers['content-type']).toMatch(/application\/pdf/);
      expect(res.headers['x-preview-kind']).toBe('pdf');
    });

    test('200 streams an operating card via S3 transformToByteArray path', async () => {
      dbMock
        .expectSelect(/FROM driver_operating_cards WHERE id = \? LIMIT 1/i)
        .returns([{ file_key: 'cards/77.jpg', file_url: null }]);
      const bytes = new Uint8Array([1, 2, 3, 4]);
      s3Mock.s3.send.mockImplementationOnce(async () => ({
        Body: { transformToByteArray: async () => bytes },
        ContentType: 'image/jpeg',
        ContentLength: 4,
      }));
      const res = await request(app())
        .get('/api/admin/documents/77/preview?kind=operating_card')
        .set(authHeader(adminToken));
      expect(res.status).toBe(200);
      expect(res.headers['x-preview-kind']).toBe('image');
    });

    test('500 when S3 send throws', async () => {
      dbMock
        .expectSelect(/FROM compliance_documents WHERE document_id = \? LIMIT 1/i)
        .returns([{ document_url: 'docs/x.pdf' }]);
      s3Mock.s3.send.mockImplementationOnce(async () => {
        throw new Error('s3 5xx');
      });
      const res = await request(app())
        .get('/api/admin/documents/55/preview')
        .set(authHeader(adminToken));
      expect(res.status).toBe(500);
    });

    test('500 when Body has no streaming method', async () => {
      dbMock
        .expectSelect(/FROM compliance_documents WHERE document_id = \? LIMIT 1/i)
        .returns([{ document_url: 'docs/x.pdf' }]);
      s3Mock.s3.send.mockImplementationOnce(async () => ({
        Body: { weird: true },
        ContentType: 'application/octet-stream',
      }));
      const res = await request(app())
        .get('/api/admin/documents/55/preview')
        .set(authHeader(adminToken));
      expect(res.status).toBe(500);
    });
  });

  describe('previewDocumentByQuery happy path + catch', () => {
    test('200 streams a key from query url', async () => {
      const fakeBody = Readable.from([Buffer.from('hi')]);
      s3Mock.s3.send.mockImplementationOnce(async () => ({
        Body: fakeBody,
        ContentType: 'image/png',
        ContentLength: 2,
      }));
      const res = await request(app())
        .get(`/api/admin/documents/preview?url=${encodeURIComponent('docs/a.png')}`)
        .set(authHeader(adminToken));
      expect(res.status).toBe(200);
      expect(res.headers['x-preview-kind']).toBe('image');
    });

    test('500 when key resolves but S3 throws', async () => {
      s3Mock.s3.send.mockImplementationOnce(async () => {
        throw new Error('s3 boom');
      });
      const res = await request(app())
        .get(`/api/admin/documents/preview?url=${encodeURIComponent('docs/a.png')}`)
        .set(authHeader(adminToken));
      expect(res.status).toBe(500);
    });
  });

  describe('verifyOperatingCard error paths', () => {
    test('400 when status is missing', async () => {
      const res = await request(app())
        .post('/api/admin/operating-cards/77/verify')
        .set(authHeader(adminToken))
        .send({});
      expect(res.status).toBe(400);
    });

    test('500 when OperatingCard.updateStatus throws', async () => {
      dbMock
        .expectUpdate(/UPDATE driver_operating_cards/i)
        .rejectsWith(new Error('db down'));
      const res = await request(app())
        .post('/api/admin/operating-cards/77/verify')
        .set(authHeader(adminToken))
        .send({ status: 'verified' });
      expect(res.status).toBe(500);
    });
  });

  describe('overviewCharts — string date branch + empty bid map', () => {
    test('200 normalises string-formatted DATE columns', async () => {
      dbMock
        .expectSelect(/FROM shipments\s+WHERE created_at >= DATE_SUB/i)
        .returns([{ d: '2026-05-26T00:00:00.000Z', c: '7' }]);
      dbMock
        .expectSelect(/FROM bids\s+WHERE created_at >= DATE_SUB/i)
        .returns([]);
      const res = await request(app())
        .get('/api/admin/overview-charts')
        .set(authHeader(adminToken));
      expect(res.status).toBe(200);
      expect(res.body.data.series).toHaveLength(7);
    });

    test('200 ignores null DATE values from MySQL', async () => {
      dbMock
        .expectSelect(/FROM shipments\s+WHERE created_at >= DATE_SUB/i)
        .returns([{ d: null, c: 1 }]);
      dbMock
        .expectSelect(/FROM bids\s+WHERE created_at >= DATE_SUB/i)
        .returns([{ d: '2026-05-25', c: 4 }]);
      const res = await request(app())
        .get('/api/admin/overview-charts')
        .set(authHeader(adminToken));
      expect(res.status).toBe(200);
      expect(res.body.data.series).toHaveLength(7);
    });
  });
});
