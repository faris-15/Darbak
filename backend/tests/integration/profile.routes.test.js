/**
 * Integration tests for /api/profile/* (profileController + profileService +
 * profileRoutes).
 *
 * profileService.buildProfileResponse loads stats from Shipment + Rating +
 * ComplianceDocument. We drive each through dbMock.
 */
'use strict';

const request = require('supertest');

const { buildTestApp } = require('../helpers/testApp');
const { dbMock } = require('../helpers/db');
const {
  tokenForDriver,
  tokenForShipper,
  authHeader,
} = require('../helpers/auth');
const { userFactory } = require('../helpers/factories');
const s3Mock = require('../helpers/s3Mock');
const { encryptText } = require('../../utils/encryption');

const app = () => buildTestApp({ routes: ['profile'] });

const expectUserById = (row) =>
  dbMock.expectSelect(/SELECT \* FROM users WHERE id = \?/i).returns(row ? [row] : []);

const expectDriverStats = (completed = 5, earnings = 10000) =>
  dbMock
    .expectSelect(/SELECT COUNT\(\*\) as completed_trips, SUM\(final_price\)/i)
    .returns([{ completed_trips: completed, total_earnings: earnings }]);

const expectShipperStats = (total = 4, delivered = 3, active = 1) =>
  dbMock
    .expectSelect(/SELECT.*total_shipments.*delivered_shipments/is)
    .returns([{ total_shipments: total, delivered_shipments: delivered, active_shipments: active }]);

const expectAvgRating = (avg = 4.5, total = 12) =>
  dbMock
    .expectSelect(/AVG\(CASE WHEN stars BETWEEN/i)
    .returns([{ average_rating: avg, total_ratings: total }]);

const expectCompliance = (rows = []) =>
  dbMock
    .expectSelect(/FROM compliance_documents/i)
    .returns(rows);

describe('GET /api/profile/me', () => {
  test('401 without auth', async () => {
    const res = await request(app()).get('/api/profile/me');
    expect(res.status).toBe(401);
  });

  test('404 when user not found', async () => {
    expectUserById(null);
    const res = await request(app())
      .get('/api/profile/me')
      .set(authHeader(tokenForDriver(100)));
    expect(res.status).toBe(404);
  });

  test('200 builds driver profile with stats, rating, and encrypted fields decrypted', async () => {
    expectUserById(
      userFactory({
        id: 100,
        role: 'driver',
        license_no: encryptText('LIC-123'),
        commercial_no: null,
        profile_image_url: 'profile/abc.jpg',
      })
    );
    expectDriverStats(7, 50000);
    expectAvgRating(4.0, 5);
    expectCompliance([
      { document_type: 'license', document_url: 'docs/lic.pdf' },
      { document_type: 'vehicle_insurance', document_url: 'docs/ins.pdf', document_id: 'INS1' },
    ]);
    const res = await request(app())
      .get('/api/profile/me')
      .set(authHeader(tokenForDriver(100)));
    expect(res.status).toBe(200);
    expect(res.body.data).toMatchObject({
      id: 100,
      role: 'driver',
      license_no: 'LIC-123',
      completed_trips: 7,
      total_earnings: 50000,
      average_rating: '4.00',
      ratings_total: 5,
      vehicle_insurance_document_url: 'docs/ins.pdf',
      vehicle_insurance_document_id: 'INS1',
    });
    expect(res.body.data.profile_image_url).toMatch(/test-s3.local/);
  });

  test('200 builds shipper profile with shipper stats', async () => {
    expectUserById(userFactory({ id: 200, role: 'shipper' }));
    expectShipperStats(10, 8, 2);
    expectAvgRating(0, 0);
    expectCompliance([]);
    const res = await request(app())
      .get('/api/profile/me')
      .set(authHeader(tokenForShipper(200)));
    expect(res.status).toBe(200);
    expect(res.body.data).toMatchObject({
      role: 'shipper',
      total_shipments: 10,
      delivered_shipments: 8,
      active_shipments: 2,
      average_rating: '0.00',
    });
  });

  test('200 still returns when rating + compliance lookups fail', async () => {
    expectUserById(userFactory({ id: 100, role: 'driver' }));
    expectDriverStats();
    dbMock.expectSelect(/AVG\(CASE WHEN stars BETWEEN/i).rejectsWith(new Error('rating down'));
    dbMock.expectSelect(/FROM compliance_documents/i).rejectsWith(new Error('compliance down'));
    const res = await request(app())
      .get('/api/profile/me')
      .set(authHeader(tokenForDriver(100)));
    expect(res.status).toBe(200);
    expect(res.body.data.average_rating).toBe('0.00');
    expect(res.body.data.compliance_documents).toEqual([]);
  });

  test('500 when user lookup fails outright', async () => {
    dbMock.expectSelect(/SELECT \* FROM users WHERE id = \?/i).rejectsWith(new Error('boom'));
    const res = await request(app())
      .get('/api/profile/me')
      .set(authHeader(tokenForDriver(100)));
    expect(res.status).toBe(500);
  });
});

describe('PUT /api/profile/update', () => {
  test('400 when express-validator rejects missing fullName', async () => {
    const res = await request(app())
      .put('/api/profile/update')
      .set(authHeader(tokenForDriver(100)))
      .send({ email: 'a@b.co', phone: '0500000001' });
    expect(res.status).toBe(400);
  });

  test('404 when user not found', async () => {
    expectUserById(null);
    const res = await request(app())
      .put('/api/profile/update')
      .set(authHeader(tokenForDriver(100)))
      .send({ fullName: 'Hassan', email: 'h@x.com', phone: '0500000001' });
    expect(res.status).toBe(404);
  });

  test('200 updates fields, encrypts new license, rebuilds the profile', async () => {
    // 1. existing user lookup
    expectUserById(userFactory({ id: 100, role: 'driver' }));
    // 2. UPDATE users
    dbMock.expectUpdate(/UPDATE users SET full_name = \?/i).returnsAffected(1);
    // 3. buildProfileResponse re-reads the user
    expectUserById(
      userFactory({
        id: 100,
        role: 'driver',
        license_no: encryptText('LIC-NEW'),
      })
    );
    expectDriverStats();
    expectAvgRating();
    expectCompliance();
    const res = await request(app())
      .put('/api/profile/update')
      .set(authHeader(tokenForDriver(100)))
      .send({
        fullName: '  Hassan  ',
        email: 'H@X.CO',
        phone: '0500000001',
        licenseNo: 'LIC-NEW',
      });
    expect(res.status).toBe(200);
    expect(res.body.data.license_no).toBe('LIC-NEW');
  });

  test('500 when the UPDATE explodes', async () => {
    expectUserById(userFactory({ id: 100, role: 'driver' }));
    dbMock.expectUpdate(/UPDATE users SET full_name = \?/i).rejectsWith(new Error('boom'));
    const res = await request(app())
      .put('/api/profile/update')
      .set(authHeader(tokenForDriver(100)))
      .send({ fullName: 'Hassan', email: 'h@x.com', phone: '0500000001' });
    expect(res.status).toBe(500);
  });
});

describe('POST /api/profile/upload-image', () => {
  test('401 without auth', async () => {
    const res = await request(app())
      .post('/api/profile/upload-image')
      .send({});
    expect(res.status).toBe(401);
  });

  test('400 when no file uploaded', async () => {
    const res = await request(app())
      .post('/api/profile/upload-image')
      .set(authHeader(tokenForDriver(100)))
      .send({});
    expect(res.status).toBe(400);
  });

  test('404 when user does not exist — orphan file is cleaned up', async () => {
    expectUserById(null);
    const res = await request(app())
      .post('/api/profile/upload-image')
      .set(authHeader(tokenForDriver(100)))
      .send({ profileImage: 'profile/new.jpg' });
    expect(res.status).toBe(404);
    expect(s3Mock.deleteS3Object).toHaveBeenCalledWith('profile/new.jpg');
  });

  test('200 stores key, deletes previous key, returns presigned URL', async () => {
    expectUserById(userFactory({ id: 100, profile_image_url: 'profile/old.jpg' }));
    dbMock.expectUpdate(/UPDATE users SET profile_image_url = \?/i).returnsAffected(1);
    const res = await request(app())
      .post('/api/profile/upload-image')
      .set(authHeader(tokenForDriver(100)))
      .send({ profileImage: 'profile/new.jpg' });
    expect(res.status).toBe(200);
    expect(res.body.profileImageKey).toBe('profile/new.jpg');
    expect(s3Mock.deleteS3Object).toHaveBeenCalledWith('profile/old.jpg');
    expect(res.body.profileImageUrl).toMatch(/test-s3.local/);
  });

  test('500 when DB update reports 0 rows — the orphan file is cleaned up', async () => {
    expectUserById(userFactory({ id: 100, profile_image_url: null }));
    dbMock.expectUpdate(/UPDATE users SET profile_image_url = \?/i).returnsAffected(0);
    const res = await request(app())
      .post('/api/profile/upload-image')
      .set(authHeader(tokenForDriver(100)))
      .send({ profileImage: 'profile/new.jpg' });
    expect(res.status).toBe(500);
    expect(s3Mock.deleteS3Object).toHaveBeenCalledWith('profile/new.jpg');
  });
});

describe('DELETE /api/profile/remove-image', () => {
  test('401 without auth', async () => {
    const res = await request(app()).delete('/api/profile/remove-image');
    expect(res.status).toBe(401);
  });

  test('404 when user missing', async () => {
    expectUserById(null);
    const res = await request(app())
      .delete('/api/profile/remove-image')
      .set(authHeader(tokenForDriver(100)));
    expect(res.status).toBe(404);
  });

  test('200 clears the image and removes the previous key from S3', async () => {
    expectUserById(userFactory({ id: 100, profile_image_url: 'profile/old.jpg' }));
    dbMock.expectUpdate(/UPDATE users SET profile_image_url = \?/i).returnsAffected(1);
    const res = await request(app())
      .delete('/api/profile/remove-image')
      .set(authHeader(tokenForDriver(100)));
    expect(res.status).toBe(200);
    expect(res.body.profile_image_url).toBeNull();
    expect(s3Mock.deleteS3Object).toHaveBeenCalledWith('profile/old.jpg');
  });

  test('500 when update fails', async () => {
    expectUserById(userFactory({ id: 100, profile_image_url: 'profile/old.jpg' }));
    dbMock.expectUpdate(/UPDATE users SET profile_image_url = \?/i).rejectsWith(new Error('x'));
    const res = await request(app())
      .delete('/api/profile/remove-image')
      .set(authHeader(tokenForDriver(100)));
    expect(res.status).toBe(500);
  });
});
