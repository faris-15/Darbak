/**
 * Focused profileController branch tests.
 *
 * Route-level integration tests cover the authenticated happy/error paths.
 * These tests exercise controller guards and best-effort cleanup branches that
 * are normally hidden behind requireAuth or async cleanup callbacks.
 */
'use strict';

const User = require('../../models/User');
const s3Config = require('../../utils/s3Config');
const profileController = require('../../controllers/profileController');

const makeRes = () => {
  const res = {
    statusCode: 200,
    body: undefined,
    status: jest.fn((code) => {
      res.statusCode = code;
      return res;
    }),
    json: jest.fn((body) => {
      res.body = body;
      return res;
    }),
  };
  return res;
};

describe('profileController unauthenticated guards', () => {
  test('getMyProfile returns 401 when req.user is missing', async () => {
    const res = makeRes();
    await profileController.getMyProfile({ user: null }, res);
    expect(res.status).toHaveBeenCalledWith(401);
  });

  test('updateMyProfile returns 401 when req.user is missing', async () => {
    const res = makeRes();
    await profileController.updateMyProfile({ user: null, body: {} }, res);
    expect(res.status).toHaveBeenCalledWith(401);
  });

  test('uploadProfileImage returns 401 before touching uploaded file when req.user is missing', async () => {
    const res = makeRes();
    await profileController.uploadProfileImage(
      { user: null, file: { key: 'profile/orphan.jpg' } },
      res,
    );
    expect(res.status).toHaveBeenCalledWith(401);
    expect(s3Config.deleteS3Object).not.toHaveBeenCalledWith('profile/orphan.jpg');
  });

  test('removeProfileImage returns 401 when req.user is missing', async () => {
    const res = makeRes();
    await profileController.removeProfileImage({ user: null }, res);
    expect(res.status).toHaveBeenCalledWith(401);
  });
});

describe('profileController cleanup and catch branches', () => {
  afterEach(() => {
    jest.restoreAllMocks();
  });

  test('uploadProfileImage logs but succeeds when deleting previous image fails', async () => {
    jest.spyOn(User, 'findById').mockResolvedValueOnce({
      id: 100,
      profile_image_url: 'profile/old.jpg',
    });
    jest.spyOn(User, 'updateProfileImage').mockResolvedValueOnce(true);
    s3Config.deleteS3Object.mockRejectedValueOnce(new Error('s3 delete failed'));
    s3Config.generatePresignedUrl.mockResolvedValueOnce('https://test-s3.local/profile/new.jpg');

    const res = makeRes();
    await profileController.uploadProfileImage(
      { user: { id: 100 }, file: { key: 'profile/new.jpg' } },
      res,
    );

    expect(res.statusCode).toBe(200);
    expect(res.body.profileImageKey).toBe('profile/new.jpg');
    expect(s3Config.deleteS3Object).toHaveBeenCalledWith('profile/old.jpg');
  });

  test('uploadProfileImage cleans uploaded file when User.findById throws', async () => {
    jest.spyOn(User, 'findById').mockRejectedValueOnce(new Error('db down'));

    const res = makeRes();
    await profileController.uploadProfileImage(
      { user: { id: 100 }, file: { key: 'profile/new.jpg' } },
      res,
    );

    expect(res.status).toHaveBeenCalledWith(500);
    expect(s3Config.deleteS3Object).toHaveBeenCalledWith('profile/new.jpg');
  });

  test('removeProfileImage logs but succeeds when deleting previous image fails', async () => {
    jest.spyOn(User, 'findById').mockResolvedValueOnce({
      id: 100,
      profile_image_url: 'profile/old.jpg',
    });
    jest.spyOn(User, 'updateProfileImage').mockResolvedValueOnce(true);
    s3Config.deleteS3Object.mockRejectedValueOnce(new Error('s3 delete failed'));

    const res = makeRes();
    await profileController.removeProfileImage({ user: { id: 100 } }, res);

    expect(res.statusCode).toBe(200);
    expect(res.body.profileImageKey).toBeNull();
    expect(s3Config.deleteS3Object).toHaveBeenCalledWith('profile/old.jpg');
  });
});
