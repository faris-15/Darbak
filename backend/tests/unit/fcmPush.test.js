/**
 * Unit tests for utils/fcmPush. We bypass the global jest mock with
 * `jest.requireActual` and stub `firebaseAdminApp` so we can drive the
 * messaging flow deterministically.
 */
'use strict';

jest.mock('../../utils/firebaseAdminApp', () => ({
  getFirebaseAdminApp: jest.fn(),
}));

const { getFirebaseAdminApp } = require('../../utils/firebaseAdminApp');
const { dbMock } = require('../helpers/db');

const loadFcm = () => jest.requireActual('../../utils/fcmPush');

describe('fcmPush.sendPushToUser', () => {
  beforeEach(() => {
    getFirebaseAdminApp.mockReset();
  });

  test('returns sent:false / reason:no_admin when admin sdk is not available', async () => {
    getFirebaseAdminApp.mockReturnValue(null);
    const { sendPushToUser } = loadFcm();
    const result = await sendPushToUser(100, { title: 'T', body: 'B' });
    expect(result).toEqual({ sent: false, reason: 'no_admin' });
  });

  test('returns sent:false / reason:db when fcm_token lookup fails', async () => {
    getFirebaseAdminApp.mockReturnValue({ messaging: () => ({ send: jest.fn() }) });
    dbMock
      .expectSelect(/SELECT fcm_token FROM users WHERE id = \?/i)
      .rejectsWith(new Error('boom'));
    const { sendPushToUser } = loadFcm();
    const result = await sendPushToUser(100, { title: 'T', body: 'B' });
    expect(result).toEqual({ sent: false, reason: 'db' });
  });

  test('returns sent:false / reason:no_token when user has no fcm_token', async () => {
    getFirebaseAdminApp.mockReturnValue({ messaging: () => ({ send: jest.fn() }) });
    dbMock
      .expectSelect(/SELECT fcm_token FROM users WHERE id = \?/i)
      .returns([{ fcm_token: null }]);
    const { sendPushToUser } = loadFcm();
    const result = await sendPushToUser(100, { title: 'T', body: 'B' });
    expect(result).toEqual({ sent: false, reason: 'no_token' });
  });

  test('sends notification when token is available', async () => {
    const send = jest.fn(async () => 'ok');
    getFirebaseAdminApp.mockReturnValue({ messaging: () => ({ send }) });
    dbMock
      .expectSelect(/SELECT fcm_token FROM users WHERE id = \?/i)
      .returns([{ fcm_token: 'abc' }]);
    const { sendPushToUser } = loadFcm();
    const result = await sendPushToUser(100, {
      title: 'T',
      body: 'B',
      data: { type: 'x' },
    });
    expect(send).toHaveBeenCalledWith({
      token: 'abc',
      notification: { title: 'T', body: 'B' },
      data: { type: 'x' },
    });
    expect(result).toEqual({ sent: true });
  });

  test('returns sent:false with reason when admin.send fails', async () => {
    const send = jest.fn(async () => {
      throw new Error('quota exceeded');
    });
    getFirebaseAdminApp.mockReturnValue({ messaging: () => ({ send }) });
    dbMock
      .expectSelect(/SELECT fcm_token FROM users WHERE id = \?/i)
      .returns([{ fcm_token: 'abc' }]);
    const { sendPushToUser } = loadFcm();
    const result = await sendPushToUser(100, { title: 'T', body: 'B' });
    expect(result).toEqual({ sent: false, reason: 'quota exceeded' });
  });
});
