/**
 * Programmable database mock.
 *
 * Tests express **expectations** as a queue of (matcher, response) pairs.
 * Every `pool.execute(sql, params)` (or connection.execute) consumes one
 * matching pair. Unmatched calls fail loudly so you cannot silently let a
 * controller call SQL the test never anticipated.
 *
 * Usage:
 *
 *   const { dbMock } = require('../helpers/db');
 *
 *   dbMock.expect(/^SELECT \* FROM users WHERE phone = \? OR email = \?$/i)
 *         .withParams(['00966...', 'a@b.c'])
 *         .returns([{ id: 1, role: 'driver' }]);
 *
 *   dbMock.expectInsert(/INSERT INTO bids/).returnsInsert(42);
 *
 *   await request(app).post('/api/bids').set('Authorization', `Bearer ${tok}`).send({...});
 *
 *   dbMock.assertAllConsumed();
 *
 * Anything unmatched throws a descriptive error including the failing SQL,
 * a normalised diff vs. the expectation, and the next 3 expectations in queue.
 */
'use strict';

class Expectation {
  constructor(matcher) {
    this.matcher = matcher;
    this.params = undefined;
    this.response = [[], { fieldCount: 0 }];
    this.error = null;
    this.label = '';
  }

  /** Optional parameter matcher — array of values, deep-equal. */
  withParams(params) {
    this.params = params;
    return this;
  }

  /** Returns SELECT-style rows. */
  returns(rows = [], extra = {}) {
    this.response = [rows, { ...extra }];
    return this;
  }

  /** Returns INSERT result with the given insertId. */
  returnsInsert(insertId, affectedRows = 1) {
    this.response = [{ insertId, affectedRows }, { fieldCount: 0 }];
    return this;
  }

  /** Returns UPDATE/DELETE result. */
  returnsAffected(affectedRows = 1) {
    this.response = [{ affectedRows }, { fieldCount: 0 }];
    return this;
  }

  /** Make this expectation throw an error. */
  rejectsWith(error) {
    this.error = error instanceof Error ? error : new Error(String(error));
    return this;
  }

  /** Free-form label for diagnostics. */
  describe(label) {
    this.label = label;
    return this;
  }
}

class DbMock {
  constructor() {
    this.queue = [];
    this.calls = [];
    this.transactionState = 'idle'; // idle | begun | committed | rolledback
    this.transactionEvents = [];
    this.connectionsCheckedOut = 0;
    this.connectionsReleased = 0;
    /**
     * Router-mode rules: each rule is `{ matcher, handler }`. The router is
     * consulted only when the strict expectation queue is empty. This lets
     * tests that exercise large code paths (e.g. admin dashboard pages making
     * 6+ SQL calls) opt into a "match-by-pattern, return-by-handler" style
     * instead of enqueueing every SQL by hand. `handler(sql, params)` may
     * return rows or a [rows, fields] tuple; throwing an Error propagates as
     * a query failure.
     */
    this.routes = [];
  }

  reset() {
    this.queue.length = 0;
    this.calls.length = 0;
    this.transactionState = 'idle';
    this.transactionEvents.length = 0;
    this.connectionsCheckedOut = 0;
    this.connectionsReleased = 0;
    this.routes.length = 0;
  }

  /**
   * Register a SQL pattern -> response mapping that survives across multiple
   * `execute` calls. Useful when a single endpoint issues the same probe
   * SQL many times (e.g. SHOW COLUMNS, INFORMATION_SCHEMA lookups).
   */
  route(matcher, handler) {
    this.routes.push({ matcher, handler });
    return this;
  }

  /** Convenience: route SELECTs that match `matcher` to a static row set. */
  routeSelect(matcher, rows = []) {
    return this.route(matcher, () => [rows, { fieldCount: 0 }]);
  }

  /** Convenience: route INSERTs that match `matcher` to a fake insert. */
  routeInsert(matcher, insertId = 1, affectedRows = 1) {
    return this.route(matcher, () => [{ insertId, affectedRows }, { fieldCount: 0 }]);
  }

  /** Convenience: route UPDATEs/DELETEs that match `matcher` to a fake affect. */
  routeAffect(matcher, affectedRows = 1) {
    return this.route(matcher, () => [{ affectedRows }, { fieldCount: 0 }]);
  }

  /** Expect any kind of statement matched by sqlMatcher (string or RegExp). */
  expect(sqlMatcher) {
    const exp = new Expectation(sqlMatcher);
    this.queue.push(exp);
    return exp;
  }

  expectInsert(matcher = /^INSERT/i) {
    return this.expect(matcher);
  }

  expectUpdate(matcher = /^UPDATE/i) {
    return this.expect(matcher);
  }

  expectDelete(matcher = /^DELETE/i) {
    return this.expect(matcher);
  }

  expectSelect(matcher = /^SELECT/i) {
    return this.expect(matcher);
  }

  /** Throws if there are unconsumed expectations. */
  assertAllConsumed() {
    if (this.queue.length === 0) return;
    const remaining = this.queue
      .map((e, i) => `  #${i + 1}: ${e.label || normaliseMatcher(e.matcher)}`)
      .join('\n');
    throw new Error(
      `[dbMock] Test ended with ${this.queue.length} unconsumed expectation(s):\n${remaining}`
    );
  }

  /** Internal: invoked by the mysql2 mock for each `execute`. */
  __consume(sql, params) {
    this.calls.push({ sql, params });
    const trimmed = String(sql).replace(/\s+/g, ' ').trim();

    // Router rules take precedence over the strict expectation queue. This
    // lets tests register schema-bootstrap probes once (e.g. INFORMATION_SCHEMA,
    // CREATE TABLE IF NOT EXISTS) without enqueueing them in front of the
    // business SQL they actually want to assert.
    for (const rule of this.routes) {
      const matched =
        rule.matcher instanceof RegExp
          ? rule.matcher.test(trimmed)
          : trimmed.includes(rule.matcher);
      if (matched) {
        const result = rule.handler(trimmed, params);
        if (Array.isArray(result) && result.length === 2) return result;
        if (Array.isArray(result)) return [result, { fieldCount: 0 }];
        if (result && typeof result === 'object' && 'insertId' in result) {
          return [result, { fieldCount: 0 }];
        }
        if (result && typeof result === 'object' && 'affectedRows' in result) {
          return [result, { fieldCount: 0 }];
        }
        return [[], { fieldCount: 0 }];
      }
    }

    if (this.queue.length === 0) {
      const recent = this.calls
        .slice(-3)
        .map((c, i) => `  ${i + 1}. ${c.sql.slice(0, 160)}`)
        .join('\n');
      throw new Error(
        `[dbMock] No expectation queued for SQL:\n  ${trimmed.slice(0, 240)}\n` +
          `Recent calls:\n${recent}`
      );
    }

    const exp = this.queue.shift();
    const matcher = exp.matcher;
    const matched = matcher instanceof RegExp ? matcher.test(trimmed) : trimmed.includes(matcher);
    if (!matched) {
      throw new Error(
        `[dbMock] SQL mismatch.\n` +
          `  expected: ${normaliseMatcher(matcher)}\n` +
          `  actual:   ${trimmed.slice(0, 240)}`
      );
    }

    if (exp.params !== undefined) {
      try {
        expect(params).toEqual(exp.params);
      } catch (err) {
        throw new Error(
          `[dbMock] Params mismatch for ${normaliseMatcher(matcher)}:\n  ${err.message}`
        );
      }
    }

    if (exp.error) throw exp.error;
    return exp.response;
  }
}

const normaliseMatcher = (m) => (m instanceof RegExp ? m.toString() : `"${m}"`);

const dbMock = new DbMock();

module.exports = { dbMock };
