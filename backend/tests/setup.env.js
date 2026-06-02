/**
 * Loaded BEFORE the Jest test framework (so it runs before any module under
 * test is required). We use this to:
 *
 *   1. Force `NODE_ENV=test` so any production-only side effects are skipped.
 *   2. Inject deterministic JWT/encryption keys. The encryption module throws
 *      at require-time if these are missing, so we set them here rather than
 *      relying on developers having a populated `.env` on their machines.
 *   3. Disable the daily late-delivery cron, the real DB connect probe, and
 *      Firebase service account loading.
 *
 * NEVER add real secrets here. The hex strings below are deterministic test
 * fixtures only.
 */
'use strict';

process.env.NODE_ENV = 'test';

// JWT
process.env.JWT_SECRET = process.env.JWT_SECRET || 'test_jwt_secret_do_not_use_in_prod';

// AES-256-CBC: 32-byte key + 16-byte IV (hex)
process.env.ENCRYPTION_KEY =
  process.env.ENCRYPTION_KEY ||
  '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
process.env.ENCRYPTION_IV =
  process.env.ENCRYPTION_IV || '0123456789abcdef0123456789abcdef';

// Disable cron to keep Jest from leaking timers
process.env.DISABLE_DELIVERY_PENALTY_CRON = '1';

// Provide harmless DB defaults; the real `mysql2` module is mocked, but the
// pool factory still reads these on import.
process.env.MYSQL_HOST = 'localhost';
process.env.MYSQL_USER = 'test';
process.env.MYSQL_PASSWORD = 'test';
process.env.MYSQL_DATABASE = 'darbak_test';
process.env.MYSQL_PORT = '3306';

// Firebase: never load a real service account in tests
delete process.env.FIREBASE_SERVICE_ACCOUNT_PATH;
delete process.env.FIREBASE_WEB_API_KEY;

// Silence noisy console output unless explicitly opted in
if (!process.env.VERBOSE_TESTS) {
  for (const method of ['log', 'info', 'warn', 'debug']) {
    // eslint-disable-next-line no-console
    console[method] = () => {};
  }
}
