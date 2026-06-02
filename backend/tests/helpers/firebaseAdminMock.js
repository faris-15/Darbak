/**
 * Mock for utils/firebaseAdminApp.js. By default returns null (Firebase
 * disabled). Tests that exercise Firebase Auth flows can replace the
 * exported function via:
 *
 *   const firebase = require('../helpers/firebaseAdminMock');
 *   firebase.__setApp({
 *     auth: () => ({
 *       verifyIdToken: jest.fn(async () => ({ email: 'a@b.c' })),
 *       getUserByEmail: jest.fn(async () => ({ uid: 'fb-1' })),
 *       createUser: jest.fn(async () => ({ uid: 'fb-1' })),
 *     }),
 *   });
 */
'use strict';

let stub = null;

const firebaseAdminMock = {
  getFirebaseAdminApp: jest.fn(() => stub),
  __setApp(app) {
    stub = app;
  },
  __reset() {
    stub = null;
  },
};

module.exports = firebaseAdminMock;
