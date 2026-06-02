/**
 * Runs after Jest is initialised. Installs **module-level** mocks for every
 * external dependency used by the backend so individual test files do not
 * have to repeat the boilerplate:
 *
 *   - mysql2/promise   -> in-memory pool with programmable response queue
 *   - aws-sdk S3       -> no-op presigner & deleter
 *   - firebase-admin   -> rejects unless a test stubs it explicitly
 *   - fcmPush          -> no-op
 *   - global fetch     -> rejects so any unmocked HTTP call is loud
 *
 * Tests that need a different behaviour can:
 *   - import { dbMock } from 'tests/helpers/db' and queue rows
 *   - jest.spyOn the relevant exported function
 *   - call dbMock.reset() in afterEach
 */
'use strict';

jest.mock('mysql2/promise', () => require('./helpers/mysql2Mock'));
jest.mock('../utils/s3Config', () => require('./helpers/s3Mock'));
jest.mock('../utils/firebaseAdminApp', () => require('./helpers/firebaseAdminMock'));
jest.mock('../utils/fcmPush', () => require('./helpers/fcmPushMock'));
jest.mock('../utils/adminRealtime', () => require('./helpers/adminRealtimeMock'));
jest.mock('../services/contractPdfService', () => ({
  generateAndStoreShipmentContract: jest.fn(async () => ({
    contract_id: 1,
    pdf_key: 'contracts/test.pdf',
  })),
}));

// Schema-ensuring helpers issue ALTER TABLE / INFORMATION_SCHEMA queries.
// We treat them as no-ops in tests so we only assert the *business* SQL.
jest.mock('../utils/profileImageSchema', () => ({
  ensureProfileImageSchema: jest.fn(async () => {}),
}));
jest.mock('../utils/messageStatusSchema', () => ({
  ensureMessageStatusSchema: jest.fn(async () => {}),
}));
jest.mock('../utils/truckClassificationSchema', () => ({
  ensureTruckClassificationSchema: jest.fn(async () => {}),
}));
jest.mock('../utils/shipmentTruckSchema', () => ({
  ensureShipmentTruckSchema: jest.fn(async () => {}),
}));
jest.mock('../utils/truckInsuranceSchema', () => ({
  ensureTruckInsuranceSchema: jest.fn(async () => {}),
}));

// Notification model has its own private ensureNotificationShipmentSchema()
// that fires INFORMATION_SCHEMA probes on every create. Mock the model so the
// rest of the suite does not need to enqueue those probes per test. Tests
// that care about notifications can still assert via `Notification.create`.
jest.mock('../models/Notification', () => ({
  create: jest.fn(async (payload) => ({ id: 999_000, ...payload, created_at: new Date() })),
  findByUserId: jest.fn(async () => []),
  findById: jest.fn(async () => null),
  markAsRead: jest.fn(async () => true),
  markAllAsRead: jest.fn(async () => true),
  delete: jest.fn(async () => true),
  deleteOldNotifications: jest.fn(async () => 0),
  getUnreadCount: jest.fn(async () => 0),
}));

// Rating model uses a runtime SHOW COLUMNS to discover legacy column names.
// Stub the column map so consumers don't need to enqueue that probe.
jest.mock('../models/Rating', () => {
  const real = jest.requireActual('../models/Rating');
  return {
    ...real,
    getColumnMap: jest.fn(async () => ({
      ratedColumn: 'rated_id',
      starsColumn: 'stars',
      commentColumn: 'comment',
      hasRaterRole: false,
      hasCreatedAt: true,
    })),
  };
});

// Refuse unmocked outbound HTTP traffic — any test that needs `fetch` must
// stub it explicitly via jest.spyOn(globalThis, 'fetch').
const { dbMock } = require('./helpers/db');
const s3Mock = require('./helpers/s3Mock');
const firebaseAdminMock = require('./helpers/firebaseAdminMock');
const fcmPushMock = require('./helpers/fcmPushMock');

beforeEach(() => {
  dbMock.reset();
  s3Mock.__reset();
  firebaseAdminMock.__reset();
  fcmPushMock.__reset();
    if (!process.env.VERBOSE_TESTS) {
      jest.spyOn(console, 'error').mockImplementation(() => {});
      jest.spyOn(console, 'log').mockImplementation(() => {});
      jest.spyOn(console, 'warn').mockImplementation(() => {});
    }
  globalThis.fetch = jest.fn(async () => {
    throw new Error(
      '[tests] outbound fetch() blocked. Stub it with jest.spyOn(globalThis, "fetch").'
    );
  });

    // Globally satisfy schema-discovery probes from the Rating model so each
    // test only needs to enqueue its business SQL. Production schema uses the
    // newer column names — that matches what the per-test factories expect.
    dbMock.route(/^SHOW COLUMNS FROM ratings/i, () => [
      [
        { Field: 'id' },
        { Field: 'shipment_id' },
        { Field: 'rater_id' },
        { Field: 'rated_id' },
        { Field: 'stars' },
        { Field: 'comment' },
        { Field: 'created_at' },
      ],
      { fieldCount: 0 },
    ]);

    // The Notification model probes INFORMATION_SCHEMA on first use to add
    // missing columns/indexes. We model production where the schema is
    // already in place, so simply return `count = 1` for every probe.
    dbMock.route(/FROM INFORMATION_SCHEMA\.COLUMNS/i, () => [
      [{ count: 1 }],
      { fieldCount: 0 },
    ]);
    dbMock.route(/FROM INFORMATION_SCHEMA\.STATISTICS/i, () => [
      [{ count: 1 }],
      { fieldCount: 0 },
    ]);
});

afterAll(() => {
  jest.restoreAllMocks();
});
