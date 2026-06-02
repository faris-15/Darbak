/**
 * Unit tests for the various ensure*Schema helpers. They all share the
 * same pattern: probe INFORMATION_SCHEMA, ALTER TABLE on mismatch, swallow
 * duplicate-column/key errors, but re-throw on other DB failures.
 */
'use strict';

const { dbMock } = require('../helpers/db');

// IMPORTANT: setup.js installs *first-match* routes for INFORMATION_SCHEMA
// returning count=1 (so every probe sees "column exists"). Our negative tests
// need the opposite — so we wipe the global routes before installing ours.
const routeProbeMissing = () => {
  dbMock.routes.length = 0;
  dbMock.route(/FROM INFORMATION_SCHEMA\.COLUMNS/i, () => [
    [{ count: 0 }],
    { fieldCount: 0 },
  ]);
  dbMock.route(/FROM INFORMATION_SCHEMA\.STATISTICS/i, () => [
    [{ count: 0 }],
    { fieldCount: 0 },
  ]);
  dbMock.route(/FROM INFORMATION_SCHEMA\.TABLE_CONSTRAINTS/i, () => [
    [{ count: 0 }],
    { fieldCount: 0 },
  ]);
};

const routeProbeExists = () => {
  dbMock.routes.length = 0;
  dbMock.route(/FROM INFORMATION_SCHEMA\.COLUMNS/i, () => [
    [{ count: 1 }],
    { fieldCount: 0 },
  ]);
  dbMock.route(/FROM INFORMATION_SCHEMA\.STATISTICS/i, () => [
    [{ count: 1 }],
    { fieldCount: 0 },
  ]);
  dbMock.route(/FROM INFORMATION_SCHEMA\.TABLE_CONSTRAINTS/i, () => [
    [{ count: 1 }],
    { fieldCount: 0 },
  ]);
};

/**
 * Each schema helper caches its `ensurePromise` at module scope. We drop
 * the schema module from the require cache so each test gets a fresh
 * helper, while keeping our shared dbMock instance alive (the helpers/db
 * module stays cached, so `dbMock.route(...)` is visible to the helper's
 * pool).
 */
const loadReal = (name) => {
  const utilPath = require.resolve(`../../utils/${name}`);
  delete require.cache[utilPath];
  return jest.requireActual(`../../utils/${name}`);
};

describe('ensureProfileImageSchema', () => {
  test('ALTERs when column is missing', async () => {
    routeProbeMissing();
    dbMock.route(/ALTER TABLE users/i, () => [{ affectedRows: 0 }, {}]);
    const { ensureProfileImageSchema } = loadReal('profileImageSchema');
    await expect(ensureProfileImageSchema()).resolves.toBeUndefined();
  });

  test('no-ops when column already exists', async () => {
    routeProbeExists();
    const { ensureProfileImageSchema } = loadReal('profileImageSchema');
    await expect(ensureProfileImageSchema()).resolves.toBeUndefined();
  });

  test('resets cache when probe throws', async () => {
    // Override the global route to reject so the schema helper bubbles the
    // failure back to its caller and clears its module-level cache. We use
    // jest.isolateModules so the schema utility loads with a virgin
    // ensurePromise — jest.requireActual alone hits Jest's internal cache
    // and would otherwise reuse a previously-resolved promise from another
    // test in the same file.
    dbMock.routes.length = 0;
    dbMock.route(/FROM INFORMATION_SCHEMA\.COLUMNS/i, () => {
      throw new Error('boom');
    });
    let ensureProfileImageSchema;
    jest.isolateModules(() => {
      ({ ensureProfileImageSchema } = jest.requireActual(
        '../../utils/profileImageSchema',
      ));
    });
    await expect(ensureProfileImageSchema()).rejects.toThrow('boom');
  });
});

describe('ensureShipmentTruckSchema', () => {
  test('ALTERs when column missing', async () => {
    routeProbeMissing();
    dbMock.route(/ALTER TABLE shipments/i, () => [{ affectedRows: 0 }, {}]);
    const { ensureShipmentTruckSchema } = loadReal('shipmentTruckSchema');
    await expect(ensureShipmentTruckSchema()).resolves.toBeUndefined();
  });

  test('no-op when column exists', async () => {
    routeProbeExists();
    const { ensureShipmentTruckSchema } = loadReal('shipmentTruckSchema');
    await expect(ensureShipmentTruckSchema()).resolves.toBeUndefined();
  });

  test('clears cached promise and re-throws when ALTER fails', async () => {
    routeProbeMissing();
    dbMock.route(/ALTER TABLE shipments/i, () => {
      throw new Error('alter-fail');
    });
    let fresh;
    jest.isolateModules(() => {
      fresh = jest.requireActual('../../utils/shipmentTruckSchema');
    });
    await expect(fresh.ensureShipmentTruckSchema()).rejects.toThrow('alter-fail');
  });
});

describe('ensureMessageStatusSchema', () => {
  test('no-ops when all probes return existing columns/indexes', async () => {
    routeProbeExists();
    const { ensureMessageStatusSchema } = loadReal('messageStatusSchema');
    await expect(ensureMessageStatusSchema()).resolves.toBeUndefined();
  });

  test('runs ALTERs when columns are missing (duplicate errors swallowed)', async () => {
    routeProbeMissing();
    dbMock.route(/ALTER TABLE messages/i, () => {
      const err = new Error('dup');
      err.code = 'ER_DUP_FIELDNAME';
      throw err;
    });
    let fresh;
    jest.isolateModules(() => {
      fresh = jest.requireActual('../../utils/messageStatusSchema');
    });
    await expect(fresh.ensureMessageStatusSchema()).resolves.toBeUndefined();
  });

  test('swallows ER_DUP_KEYNAME race during index ALTER', async () => {
    routeProbeMissing();
    dbMock.route(/ALTER TABLE messages/i, () => {
      const err = new Error('dup-key');
      err.code = 'ER_DUP_KEYNAME';
      throw err;
    });
    let fresh;
    jest.isolateModules(() => {
      fresh = jest.requireActual('../../utils/messageStatusSchema');
    });
    await expect(fresh.ensureMessageStatusSchema()).resolves.toBeUndefined();
  });

  test('runs all ALTERs cleanly when nothing throws', async () => {
    routeProbeMissing();
    dbMock.route(/ALTER TABLE messages/i, () => [{ affectedRows: 0 }, {}]);
    let fresh;
    jest.isolateModules(() => {
      fresh = jest.requireActual('../../utils/messageStatusSchema');
    });
    await expect(fresh.ensureMessageStatusSchema()).resolves.toBeUndefined();
  });

  test('re-throws unexpected ALTER errors and clears the promise cache', async () => {
    routeProbeMissing();
    dbMock.route(/ALTER TABLE messages/i, () => {
      throw new Error('mysql-down');
    });
    let fresh;
    jest.isolateModules(() => {
      fresh = jest.requireActual('../../utils/messageStatusSchema');
    });
    await expect(fresh.ensureMessageStatusSchema()).rejects.toThrow('mysql-down');
  });
});

describe('ensureTruckClassificationSchema', () => {
  test('no-op when columns already exist (still runs idempotent migration)', async () => {
    routeProbeExists();
    dbMock.route(/ALTER TABLE trucks/i, () => [{ affectedRows: 0 }, {}]);
    dbMock.route(/^UPDATE trucks/i, () => [{ affectedRows: 0 }, {}]);
    const { ensureTruckClassificationSchema } = loadReal(
      'truckClassificationSchema',
    );
    await expect(ensureTruckClassificationSchema()).resolves.toBeUndefined();
  });

  test('runs ALTERs when columns missing', async () => {
    routeProbeMissing();
    dbMock.route(/ALTER TABLE trucks/i, () => [{ affectedRows: 0 }, {}]);
    dbMock.route(/^UPDATE trucks/i, () => [{ affectedRows: 0 }, {}]);
    let fresh;
    jest.isolateModules(() => {
      fresh = jest.requireActual('../../utils/truckClassificationSchema');
    });
    await expect(fresh.ensureTruckClassificationSchema()).resolves.toBeUndefined();
  });

  test('swallows ER_DUP_FIELDNAME during ALTER race', async () => {
    routeProbeMissing();
    dbMock.route(/ALTER TABLE trucks/i, () => {
      const err = new Error('dup');
      err.code = 'ER_DUP_FIELDNAME';
      throw err;
    });
    dbMock.route(/^UPDATE trucks/i, () => [{ affectedRows: 0 }, {}]);
    let fresh;
    jest.isolateModules(() => {
      fresh = jest.requireActual('../../utils/truckClassificationSchema');
    });
    await expect(fresh.ensureTruckClassificationSchema()).resolves.toBeUndefined();
  });

  test('clears cached promise and re-throws when ALTER fails', async () => {
    routeProbeMissing();
    dbMock.route(/ALTER TABLE trucks/i, () => {
      throw new Error('disk-broken');
    });
    dbMock.route(/^UPDATE trucks/i, () => [{ affectedRows: 0 }, {}]);
    let fresh;
    jest.isolateModules(() => {
      fresh = jest.requireActual('../../utils/truckClassificationSchema');
    });
    await expect(fresh.ensureTruckClassificationSchema()).rejects.toThrow(
      'disk-broken',
    );
  });
});

describe('ensureTruckInsuranceSchema', () => {
  test('no-op when columns already exist', async () => {
    routeProbeExists();
    const { ensureTruckInsuranceSchema } = loadReal('truckInsuranceSchema');
    await expect(ensureTruckInsuranceSchema()).resolves.toBeUndefined();
  });

  test('runs ALTERs when columns missing', async () => {
    routeProbeMissing();
    dbMock.route(/ALTER TABLE compliance_documents/i, () => [
      { affectedRows: 0 },
      {},
    ]);
    let fresh;
    jest.isolateModules(() => {
      fresh = jest.requireActual('../../utils/truckInsuranceSchema');
    });
    await expect(fresh.ensureTruckInsuranceSchema()).resolves.toBeUndefined();
  });

  test('swallows ER_DUP_FIELDNAME / ER_FK_DUP_NAME during ALTER race', async () => {
    routeProbeMissing();
    dbMock.route(/ALTER TABLE compliance_documents/i, () => {
      const err = new Error('dup');
      err.code = 'ER_DUP_FIELDNAME';
      throw err;
    });
    let fresh;
    jest.isolateModules(() => {
      fresh = jest.requireActual('../../utils/truckInsuranceSchema');
    });
    await expect(fresh.ensureTruckInsuranceSchema()).resolves.toBeUndefined();
  });

  test('swallows ER_FK_DUP_NAME during ALTER race', async () => {
    routeProbeMissing();
    dbMock.route(/ALTER TABLE compliance_documents/i, () => {
      const err = new Error('dup-fk');
      err.code = 'ER_FK_DUP_NAME';
      throw err;
    });
    let fresh;
    jest.isolateModules(() => {
      fresh = jest.requireActual('../../utils/truckInsuranceSchema');
    });
    await expect(fresh.ensureTruckInsuranceSchema()).resolves.toBeUndefined();
  });

  test('re-throws when a required ALTER fails with unknown error', async () => {
    routeProbeMissing();
    dbMock.route(/ALTER TABLE compliance_documents/i, () => {
      throw new Error('disk-full');
    });
    let fresh;
    jest.isolateModules(() => {
      fresh = jest.requireActual('../../utils/truckInsuranceSchema');
    });
    await expect(fresh.ensureTruckInsuranceSchema()).rejects.toThrow('disk-full');
  });

  test('continues when only the optional FK constraint fails', async () => {
    // Columns + indexes exist; only the FK constraint is missing. The FK
    // ALTER will throw a non-duplicate error which `safeAlter` swallows
    // because the FK ALTER is registered with `{ required: false }`.
    dbMock.route(/FROM INFORMATION_SCHEMA\.COLUMNS/i, () => [
      [{ count: 1 }],
      { fieldCount: 0 },
    ]);
    dbMock.route(/FROM INFORMATION_SCHEMA\.STATISTICS/i, () => [
      [{ count: 1 }],
      { fieldCount: 0 },
    ]);
    dbMock.route(/FROM INFORMATION_SCHEMA\.TABLE_CONSTRAINTS/i, () => [
      [{ count: 0 }],
      { fieldCount: 0 },
    ]);
    const altered = [];
    dbMock.route(/ALTER TABLE compliance_documents/i, (sql) => {
      altered.push(sql);
      if (/FOREIGN KEY/i.test(sql)) {
        throw new Error('cannot-create-fk');
      }
      return [{ affectedRows: 0 }, {}];
    });
    let fresh;
    jest.isolateModules(() => {
      fresh = jest.requireActual('../../utils/truckInsuranceSchema');
    });
    await expect(fresh.ensureTruckInsuranceSchema()).resolves.toBeUndefined();
    expect(altered.some((s) => /FOREIGN KEY/i.test(s))).toBe(true);
  });
});
