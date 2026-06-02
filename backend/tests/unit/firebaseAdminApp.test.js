/**
 * Unit tests for utils/firebaseAdminApp. We bypass the global jest mock
 * with `jest.requireActual` and stub `firebase-admin` to keep the test
 * hermetic (no real credentials needed).
 */
'use strict';

const path = require('path');

jest.mock('firebase-admin', () => ({
  __esModule: true,
  default: undefined,
  apps: [],
  initializeApp: jest.fn(),
  credential: { cert: jest.fn((c) => c) },
}));

describe('firebaseAdminApp.getFirebaseAdminApp', () => {
  let originalEnv;
  let originalApps;

  beforeEach(() => {
    jest.resetModules();
    originalEnv = process.env.FIREBASE_SERVICE_ACCOUNT_PATH;
    const admin = require('firebase-admin');
    originalApps = admin.apps;
    admin.apps = [];
    admin.initializeApp.mockClear();
  });

  afterEach(() => {
    if (originalEnv === undefined) {
      delete process.env.FIREBASE_SERVICE_ACCOUNT_PATH;
    } else {
      process.env.FIREBASE_SERVICE_ACCOUNT_PATH = originalEnv;
    }
    const admin = require('firebase-admin');
    admin.apps = originalApps;
  });

  test('returns null when env path is not set', () => {
    delete process.env.FIREBASE_SERVICE_ACCOUNT_PATH;
    const { getFirebaseAdminApp } = jest.requireActual('../../utils/firebaseAdminApp');
    expect(getFirebaseAdminApp()).toBeNull();
  });

  test('caches result between calls', () => {
    delete process.env.FIREBASE_SERVICE_ACCOUNT_PATH;
    const { getFirebaseAdminApp } = jest.requireActual('../../utils/firebaseAdminApp');
    const first = getFirebaseAdminApp();
    const second = getFirebaseAdminApp();
    expect(first).toBe(second);
  });

  test('returns null when the service account path cannot be required', () => {
    process.env.FIREBASE_SERVICE_ACCOUNT_PATH = path.join(
      __dirname,
      'non-existent-service-account.json',
    );
    const { getFirebaseAdminApp } = jest.requireActual('../../utils/firebaseAdminApp');
    expect(getFirebaseAdminApp()).toBeNull();
  });

  test('initializes firebase admin when path resolves to a valid JSON', () => {
    // Use an absolute path to any real JSON file in the repo. The
    // firebase-admin module is mocked at file scope so cert() just
    // echoes the loaded object — no schema validation runs.
    process.env.FIREBASE_SERVICE_ACCOUNT_PATH = path.resolve(
      __dirname,
      '../../package.json',
    );
    const admin = require('firebase-admin');
    admin.apps = [];
    const { getFirebaseAdminApp } = jest.requireActual(
      '../../utils/firebaseAdminApp',
    );
    const result = getFirebaseAdminApp();
    expect(admin.initializeApp).toHaveBeenCalledTimes(1);
    expect(admin.credential.cert).toHaveBeenCalled();
    expect(result).toBe(admin);
  });

  test('uses relative paths joined with cwd', () => {
    // Provide a relative path that resolves under process.cwd(). Tests
    // run from the backend folder so package.json is at the root of cwd.
    process.env.FIREBASE_SERVICE_ACCOUNT_PATH = 'package.json';
    const admin = require('firebase-admin');
    admin.apps = [];
    const { getFirebaseAdminApp } = jest.requireActual(
      '../../utils/firebaseAdminApp',
    );
    expect(getFirebaseAdminApp()).toBe(admin);
  });

  test('skips initializeApp when a default firebase app already exists', () => {
    process.env.FIREBASE_SERVICE_ACCOUNT_PATH = path.resolve(
      __dirname,
      '../../package.json',
    );
    const admin = require('firebase-admin');
    admin.apps = [{ name: '[DEFAULT]' }];
    const { getFirebaseAdminApp } = jest.requireActual(
      '../../utils/firebaseAdminApp',
    );
    const result = getFirebaseAdminApp();
    expect(admin.initializeApp).not.toHaveBeenCalled();
    expect(result).toBe(admin);
  });
});
