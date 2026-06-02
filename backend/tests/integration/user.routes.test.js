/**
 * Integration tests for /api/users/* (userController + userRoutes).
 *
 * The controller delegates to profileService.buildReviewTargetPublicProfile,
 * which in turn hits User.findById. We drive both ends via the dbMock.
 */
'use strict';

const request = require('supertest');

const { buildTestApp } = require('../helpers/testApp');
const { dbMock } = require('../helpers/db');
const { tokenForDriver, authHeader } = require('../helpers/auth');
const { userFactory } = require('../helpers/factories');

const app = () => buildTestApp({ routes: ['users'] });

describe('GET /api/users/:id/profile', () => {
  test('401 without auth', async () => {
    const res = await request(app()).get('/api/users/200/profile');
    expect(res.status).toBe(401);
  });

  test('400 when :id is not a positive integer', async () => {
    const res = await request(app())
      .get('/api/users/0/profile')
      .set(authHeader(tokenForDriver(100)));
    expect(res.status).toBe(400);
    expect(res.body.message).toMatch(/معرّف المستخدم غير صالح/);
  });

  test('400 when :id is non-numeric', async () => {
    const res = await request(app())
      .get('/api/users/abc/profile')
      .set(authHeader(tokenForDriver(100)));
    expect(res.status).toBe(400);
  });

  test('404 when the user is missing', async () => {
    dbMock.expectSelect(/FROM users WHERE id = \?/i).returns([]);
    const res = await request(app())
      .get('/api/users/999/profile')
      .set(authHeader(tokenForDriver(100)));
    expect(res.status).toBe(404);
  });

  test('200 returns the public profile for a driver target', async () => {
    dbMock.expectSelect(/FROM users WHERE id = \?/i).returns([
      userFactory({
        id: 200,
        full_name: '  شركة الشحن  ',
        role: 'shipper',
        profile_image_url: 'profile/abc.jpg',
      }),
    ]);
    const res = await request(app())
      .get('/api/users/200/profile')
      .set(authHeader(tokenForDriver(100)));
    expect(res.status).toBe(200);
    expect(res.body).toMatchObject({
      success: true,
      data: {
        id: 200,
        name: 'شركة الشحن',
        role: 'shipper',
        role_label_ar: 'شركة',
      },
    });
    expect(res.body.data.profile_image).toMatch(/test-s3.local/);
  });

  test('falls back to a generic name when full_name is blank', async () => {
    dbMock.expectSelect(/FROM users WHERE id = \?/i).returns([
      userFactory({ id: 200, full_name: '   ', role: 'driver', profile_image_url: null }),
    ]);
    const res = await request(app())
      .get('/api/users/200/profile')
      .set(authHeader(tokenForDriver(100)));
    expect(res.status).toBe(200);
    expect(res.body.data.name).toBe('مستخدم');
    expect(res.body.data.profile_image).toBeNull();
    expect(res.body.data.role).toBe('driver');
    expect(res.body.data.role_label_ar).toBe('سائق');
  });

  test('500 when the database fails', async () => {
    dbMock.expectSelect(/FROM users WHERE id = \?/i).rejectsWith(new Error('db down'));
    const res = await request(app())
      .get('/api/users/200/profile')
      .set(authHeader(tokenForDriver(100)));
    expect(res.status).toBe(500);
  });
});
