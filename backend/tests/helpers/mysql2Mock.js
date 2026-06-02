/**
 * Drop-in replacement for the `mysql2/promise` module used by
 * `backend/config/db.js`. Every `execute` call is routed through `dbMock`
 * (see ./db.js) so tests can drive controllers deterministically without
 * a real database.
 *
 * The mock also captures transactional behaviour:
 *   pool.getConnection() -> connection with begin/commit/rollback/release
 * Tests can assert these via `dbMock.transactionEvents`.
 */
'use strict';

const { dbMock } = require('./db');

const buildConnection = () => {
  dbMock.connectionsCheckedOut += 1;
  let released = false;
  return {
    execute: jest.fn(async (sql, params = []) => dbMock.__consume(sql, params)),
    query: jest.fn(async (sql, params = []) => dbMock.__consume(sql, params)),
    beginTransaction: jest.fn(async () => {
      dbMock.transactionState = 'begun';
      dbMock.transactionEvents.push('begin');
    }),
    commit: jest.fn(async () => {
      dbMock.transactionState = 'committed';
      dbMock.transactionEvents.push('commit');
    }),
    rollback: jest.fn(async () => {
      dbMock.transactionState = 'rolledback';
      dbMock.transactionEvents.push('rollback');
    }),
    release: jest.fn(() => {
      if (released) return;
      released = true;
      dbMock.connectionsReleased += 1;
      dbMock.transactionEvents.push('release');
    }),
  };
};

const pool = {
  execute: jest.fn(async (sql, params = []) => dbMock.__consume(sql, params)),
  query: jest.fn(async (sql, params = []) => dbMock.__consume(sql, params)),
  getConnection: jest.fn(async () => buildConnection()),
  end: jest.fn(async () => {}),
};

module.exports = {
  createPool: () => pool,
  __pool: pool,
};
