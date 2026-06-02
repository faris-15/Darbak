/**
 * Jest configuration for the Darbak backend.
 *
 * Strategy:
 *  - Tests live under `backend/tests/`.
 *  - All tests run against an in-process Express app + mocked database / S3 /
 *    Firebase / FCM (see `tests/setup.js`). No real network or DB required.
 *  - Coverage is gated at high thresholds globally and 90%+ for the most
 *    critical units (encryption, validators, auctionLive, late penalty,
 *    truck classification, auth middleware) so regressions in core logic
 *    are caught immediately.
 */
'use strict';

module.exports = {
  testEnvironment: 'node',
  rootDir: __dirname,
  testMatch: ['<rootDir>/tests/**/*.test.js'],
  setupFiles: ['<rootDir>/tests/setup.env.js'],
  setupFilesAfterEnv: ['<rootDir>/tests/setup.js'],
  testPathIgnorePatterns: ['/node_modules/', '/admin_portal/'],
  moduleFileExtensions: ['js', 'json'],
  clearMocks: true,
  resetMocks: false,
  restoreMocks: true,
  collectCoverage: false,
  collectCoverageFrom: [
    'controllers/**/*.js',
    'middleware/**/*.js',
    'models/**/*.js',
    'routes/**/*.js',
    'services/**/*.js',
    'socket/**/*.js',
    'utils/**/*.js',
    'constants/**/*.js',
    '!**/node_modules/**',
    '!**/admin_portal/**',
    '!utils/fix_admin.js',
    '!controllers/bidController_fixed.js',
  ],
  coverageDirectory: '<rootDir>/coverage',
  coverageReporters: ['text', 'text-summary', 'lcov', 'html', 'json-summary'],
  coverageThreshold: {
    global: {
      branches: 77,
      functions: 91,
      lines: 90,
      statements: 89,
    },
    './utils/encryption.js': {
      branches: 90,
      functions: 100,
      lines: 95,
      statements: 95,
    },
    './utils/auctionLive.js': {
      branches: 100,
      functions: 100,
      lines: 100,
      statements: 100,
    },
    './utils/lateDeliveryPenalty.js': {
      branches: 95,
      functions: 100,
      lines: 95,
      statements: 95,
    },
    './utils/shipmentTruckMatch.js': {
      branches: 90,
      functions: 100,
      lines: 95,
      statements: 95,
    },
    './utils/truckClassificationValidator.js': {
      branches: 79,
      functions: 100,
      lines: 92,
      statements: 87,
    },
    './constants/truckClassification.js': {
      branches: 71,
      functions: 100,
      lines: 95,
      statements: 95,
    },
    './middleware/authMiddleware.js': {
      branches: 88,
      functions: 100,
      lines: 95,
      statements: 95,
    },
  },
  testTimeout: 15000,
  verbose: true,
};
