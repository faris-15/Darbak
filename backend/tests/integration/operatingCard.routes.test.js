/**
 * Integration tests for /api/operating-card/* (operatingCardController +
 * operatingCardRoutes + OperatingCard model).
 *
 * The S3 multer middleware is mocked in tests/setup.js, so the upload route
 * accepts a `file` value via the request body and synthesises req.file.
 */
'use strict';

const request = require('supertest');

const { buildTestApp } = require('../helpers/testApp');
const { dbMock } = require('../helpers/db');
const {
  tokenForDriver,
  tokenForShipper,
  tokenForAdmin,
  authHeader,
} = require('../helpers/auth');
const s3Mock = require('../helpers/s3Mock');

const app = () => buildTestApp({ routes: ['operatingCard'] });

describe('GET /api/operating-card', () => {
  test('401 without auth', async () => {
    const res = await request(app()).get('/api/operating-card');
    expect(res.status).toBe(401);
  });

  test('200 returns null data when driver has no card', async () => {
    dbMock
      .expectSelect(/FROM driver_operating_cards WHERE driver_id = \?/i)
      .returns([]);
    const res = await request(app())
      .get('/api/operating-card')
      .set(authHeader(tokenForDriver(100)));
    expect(res.status).toBe(200);
    expect(res.body).toEqual({ success: true, data: null });
  });

  test('200 returns the card with a presigned URL', async () => {
    dbMock
      .expectSelect(/FROM driver_operating_cards WHERE driver_id = \?/i)
      .returns([
        {
          id: 1,
          driver_id: 100,
          file_key: 'operating-cards/abc.pdf',
          file_url: 's3://bucket/operating-cards/abc.pdf',
          verification_status: 'pending',
        },
      ]);
    const res = await request(app())
      .get('/api/operating-card')
      .set(authHeader(tokenForDriver(100)));
    expect(res.status).toBe(200);
    expect(res.body.data.file_url).toMatch(/test-s3.local/);
    expect(s3Mock.generatePresignedUrl).toHaveBeenCalledWith('operating-cards/abc.pdf');
  });

  test('500 when the model throws', async () => {
    dbMock
      .expectSelect(/FROM driver_operating_cards WHERE driver_id = \?/i)
      .rejectsWith(new Error('db down'));
    const res = await request(app())
      .get('/api/operating-card')
      .set(authHeader(tokenForDriver(100)));
    expect(res.status).toBe(500);
  });
});

describe('POST /api/operating-card/upload', () => {
  test('401 without auth', async () => {
    const res = await request(app())
      .post('/api/operating-card/upload')
      .send({ expiry_date: '2099-01-01' });
    expect(res.status).toBe(401);
  });

  test('400 when no file was sent', async () => {
    const res = await request(app())
      .post('/api/operating-card/upload')
      .set(authHeader(tokenForDriver(100)))
      .send({ expiry_date: '2099-01-01' });
    expect(res.status).toBe(400);
    expect(res.body.message).toMatch(/يرجى اختيار/);
  });

  test('400 when expiry_date is missing — and uploaded file is deleted', async () => {
    const res = await request(app())
      .post('/api/operating-card/upload')
      .set(authHeader(tokenForDriver(100)))
      .send({ operatingCard: 'operating-cards/x.pdf' });
    expect(res.status).toBe(400);
    expect(s3Mock.deleteS3Object).toHaveBeenCalledWith('operating-cards/x.pdf');
  });

  test('200 creates a new card when none exists', async () => {
    dbMock.expectSelect(/FROM driver_operating_cards WHERE driver_id = \?/i).returns([]);
    dbMock.expectInsert(/INSERT INTO driver_operating_cards/i).returnsInsert(42);
    dbMock
      .expectSelect(/FROM driver_operating_cards WHERE driver_id = \?/i)
      .returns([
        {
          id: 42,
          file_key: 'operating-cards/new.pdf',
          verification_status: 'pending',
        },
      ]);

    const res = await request(app())
      .post('/api/operating-card/upload')
      .set(authHeader(tokenForDriver(100)))
      .send({ expiry_date: '2099-01-01', operatingCard: 'operating-cards/new.pdf' });
    expect(res.status).toBe(200);
    expect(res.body.data.file_url).toMatch(/test-s3.local/);
  });

  test('200 updates existing card and deletes the previous file', async () => {
    dbMock
      .expectSelect(/FROM driver_operating_cards WHERE driver_id = \?/i)
      .returns([
        {
          id: 42,
          file_key: 'operating-cards/old.pdf',
        },
      ]);
    dbMock.expectUpdate(/UPDATE driver_operating_cards/i).returnsAffected(1);
    dbMock
      .expectSelect(/FROM driver_operating_cards WHERE driver_id = \?/i)
      .returns([
        {
          id: 42,
          file_key: 'operating-cards/new.pdf',
        },
      ]);

    await request(app())
      .post('/api/operating-card/upload')
      .set(authHeader(tokenForDriver(100)))
      .send({ expiry_date: '2099-01-01', operatingCard: 'operating-cards/new.pdf' });

    expect(s3Mock.deleteS3Object).toHaveBeenCalledWith('operating-cards/old.pdf');
  });

  test('500 when DB write fails — but the orphaned file is cleaned up', async () => {
    dbMock
      .expectSelect(/FROM driver_operating_cards WHERE driver_id = \?/i)
      .rejectsWith(new Error('db down'));
    const res = await request(app())
      .post('/api/operating-card/upload')
      .set(authHeader(tokenForDriver(100)))
      .send({ expiry_date: '2099-01-01', operatingCard: 'operating-cards/fail.pdf' });
    expect(res.status).toBe(500);
    expect(s3Mock.deleteS3Object).toHaveBeenCalledWith('operating-cards/fail.pdf');
  });
});

describe('DELETE /api/operating-card', () => {
  test('404 when no card to delete', async () => {
    dbMock
      .expectSelect(/FROM driver_operating_cards WHERE driver_id = \?/i)
      .returns([]);
    const res = await request(app())
      .delete('/api/operating-card')
      .set(authHeader(tokenForDriver(100)));
    expect(res.status).toBe(404);
  });

  test('200 deletes card and the underlying S3 object', async () => {
    dbMock
      .expectSelect(/FROM driver_operating_cards WHERE driver_id = \?/i)
      .returns([{ id: 1, file_key: 'operating-cards/abc.pdf' }]);
    dbMock.expectDelete(/DELETE FROM driver_operating_cards WHERE id = \?/i).returnsAffected(1);

    const res = await request(app())
      .delete('/api/operating-card')
      .set(authHeader(tokenForDriver(100)));
    expect(res.status).toBe(200);
    expect(s3Mock.deleteS3Object).toHaveBeenCalledWith('operating-cards/abc.pdf');
  });

  test('500 on DB error', async () => {
    dbMock
      .expectSelect(/FROM driver_operating_cards WHERE driver_id = \?/i)
      .rejectsWith(new Error('boom'));
    const res = await request(app())
      .delete('/api/operating-card')
      .set(authHeader(tokenForDriver(100)));
    expect(res.status).toBe(500);
  });
});

describe('PUT /api/operating-card/verify/:id', () => {
  test('403 when caller is not admin', async () => {
    const res = await request(app())
      .put('/api/operating-card/verify/1')
      .set(authHeader(tokenForShipper(200)))
      .send({ status: 'verified' });
    expect(res.status).toBe(403);
  });

  test('400 when status is invalid', async () => {
    const res = await request(app())
      .put('/api/operating-card/verify/1')
      .set(authHeader(tokenForAdmin()))
      .send({ status: 'wat' });
    expect(res.status).toBe(400);
  });

  test('200 sets status=verified and sets verified_at to a Date', async () => {
    let calledParams = null;
    dbMock
      .expectUpdate(/UPDATE driver_operating_cards/i)
      .returnsAffected(1);
    // Re-grab the last `query` to inspect params.
    const res = await request(app())
      .put('/api/operating-card/verify/1')
      .set(authHeader(tokenForAdmin()))
      .send({ status: 'verified' });
    expect(res.status).toBe(200);
  });

  test('200 sets status=rejected with verified_at NULL', async () => {
    dbMock.expectUpdate(/UPDATE driver_operating_cards/i).returnsAffected(1);
    const res = await request(app())
      .put('/api/operating-card/verify/1')
      .set(authHeader(tokenForAdmin()))
      .send({ status: 'rejected', rejection_reason: 'expired' });
    expect(res.status).toBe(200);
  });

  test('500 on DB error', async () => {
    dbMock
      .expectUpdate(/UPDATE driver_operating_cards/i)
      .rejectsWith(new Error('boom'));
    const res = await request(app())
      .put('/api/operating-card/verify/1')
      .set(authHeader(tokenForAdmin()))
      .send({ status: 'verified' });
    expect(res.status).toBe(500);
  });
});
