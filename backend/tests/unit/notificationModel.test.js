/**
 * Unit tests for the Notification model. The global `jest.mock` in
 * setup.js is bypassed via `jest.requireActual` to drive the *real*
 * Notification implementation (schema probes + hydrate logic + CRUD).
 */
'use strict';

const Notification = jest.requireActual('../../models/Notification');
const { dbMock } = require('../helpers/db');

describe('Notification.ensureNotificationShipmentSchema branches', () => {
  test('runs ALTER statements when columns/indexes are missing', async () => {
    // Override the global INFORMATION_SCHEMA routes so columnExists / indexExists
    // return *false* — forcing each ALTER branch to execute.
    dbMock.routes.length = 0;
    dbMock.route(/FROM INFORMATION_SCHEMA\.COLUMNS/i, () => [
      [{ count: 0 }],
      { fieldCount: 0 },
    ]);
    dbMock.route(/FROM INFORMATION_SCHEMA\.STATISTICS/i, () => [
      [{ count: 0 }],
      { fieldCount: 0 },
    ]);
    dbMock.route(/^ALTER TABLE notifications/i, () => [
      { affectedRows: 0 },
      {},
    ]);
    dbMock.expectInsert(/INSERT INTO notifications/i).returnsInsert(1);

    let fresh;
    jest.isolateModules(() => {
      fresh = jest.requireActual('../../models/Notification');
    });
    await expect(
      fresh.create({ user_id: 1, title: 't', message: 'm' }),
    ).resolves.toMatchObject({ id: 1 });
  });

  test('swallows ER_DUP_FIELDNAME during safeAlter', async () => {
    dbMock.routes.length = 0;
    dbMock.route(/FROM INFORMATION_SCHEMA\.COLUMNS/i, () => [
      [{ count: 0 }],
      { fieldCount: 0 },
    ]);
    dbMock.route(/FROM INFORMATION_SCHEMA\.STATISTICS/i, () => [
      [{ count: 0 }],
      { fieldCount: 0 },
    ]);
    dbMock.route(/^ALTER TABLE notifications/i, () => {
      const e = new Error('dup');
      e.code = 'ER_DUP_FIELDNAME';
      throw e;
    });
    dbMock.expectInsert(/INSERT INTO notifications/i).returnsInsert(2);

    let fresh;
    jest.isolateModules(() => {
      fresh = jest.requireActual('../../models/Notification');
    });
    await expect(
      fresh.create({ user_id: 1, title: 't', message: 'm' }),
    ).resolves.toMatchObject({ id: 2 });
  });

  test('re-throws non-duplicate ALTER errors and clears the cached promise', async () => {
    dbMock.routes.length = 0;
    dbMock.route(/FROM INFORMATION_SCHEMA\.COLUMNS/i, () => [
      [{ count: 0 }],
      { fieldCount: 0 },
    ]);
    dbMock.route(/FROM INFORMATION_SCHEMA\.STATISTICS/i, () => [
      [{ count: 0 }],
      { fieldCount: 0 },
    ]);
    dbMock.route(/^ALTER TABLE notifications/i, () => {
      throw new Error('alter-boom');
    });

    let fresh;
    jest.isolateModules(() => {
      fresh = jest.requireActual('../../models/Notification');
    });
    await expect(
      fresh.create({ user_id: 1, title: 't', message: 'm' }),
    ).rejects.toThrow('alter-boom');
  });
});

describe('Notification.create', () => {
  test('inserts and returns normalised payload', async () => {
    dbMock.expectInsert(/INSERT INTO notifications/i).returnsInsert(42);
    const result = await Notification.create({
      user_id: 100,
      title: 'X',
      message: 'M',
      related_shipment_id: 1000,
      related_bid_id: 500,
    });
    expect(result.id).toBe(42);
    expect(result.related_shipment_id).toBe(1000);
    expect(result.related_bid_id).toBe(500);
  });

  test('accepts camelCase aliases', async () => {
    dbMock.expectInsert(/INSERT INTO notifications/i).returnsInsert(43);
    const result = await Notification.create({
      userId: 100,
      title: 'X',
      message: 'M',
      shipmentId: 1234,
      bidId: 555,
    });
    expect(result.id).toBe(43);
    expect(result.related_shipment_id).toBe(1234);
    expect(result.related_bid_id).toBe(555);
  });

  test('drops invalid ids', async () => {
    dbMock.expectInsert(/INSERT INTO notifications/i).returnsInsert(44);
    const result = await Notification.create({
      user_id: 100,
      title: 'X',
      message: 'M',
      related_shipment_id: 'abc',
      related_bid_id: '',
    });
    expect(result.related_shipment_id).toBeNull();
    expect(result.related_bid_id).toBeNull();
  });
});

describe('Notification.findByUserId', () => {
  test('returns rows + hydrates routes when shipment id can be extracted from message', async () => {
    dbMock
      .expectSelect(/FROM notifications n\s+LEFT JOIN shipments s/i)
      .returns([
        {
          id: 1,
          user_id: 100,
          message: 'تم إنشاء عقد للشحنة #1000',
          related_shipment_id: null,
          route_description: null,
        },
      ]);
    dbMock
      .expectSelect(/SELECT id, pickup_address, dropoff_address\s+FROM shipments WHERE id IN/i)
      .returns([
        { id: 1000, pickup_address: 'الرياض', dropoff_address: 'جدة' },
      ]);
    const rows = await Notification.findByUserId(100);
    expect(rows[0].related_shipment_id).toBe(1000);
    expect(rows[0].route_description).toBe('الرياض إلى جدة');
  });

  test('honours unreadOnly flag', async () => {
    dbMock
      .expectSelect(/FROM notifications n\s+LEFT JOIN shipments s/i)
      .returns([]);
    const rows = await Notification.findByUserId(100, true);
    expect(rows).toEqual([]);
  });

  test('returns rows unchanged when route already present', async () => {
    dbMock
      .expectSelect(/FROM notifications n\s+LEFT JOIN shipments s/i)
      .returns([
        {
          id: 2,
          message: 'plain',
          route_description: 'الرياض إلى جدة',
        },
      ]);
    const rows = await Notification.findByUserId(100);
    expect(rows[0].route_description).toBe('الرياض إلى جدة');
  });
});

describe('Notification CRUD shortcuts', () => {
  test('findById returns row', async () => {
    dbMock.expectSelect(/FROM notifications WHERE id = \?/i).returns([{ id: 5 }]);
    expect((await Notification.findById(5)).id).toBe(5);
  });

  test('markAsRead returns true when row updated', async () => {
    dbMock
      .expectUpdate(/UPDATE notifications SET is_read = 1 WHERE id = \?/i)
      .returnsAffected(1);
    expect(await Notification.markAsRead(5)).toBe(true);
  });

  test('markAllAsRead returns false when nothing updated', async () => {
    dbMock
      .expectUpdate(/UPDATE notifications SET is_read = 1 WHERE user_id = \? AND is_read = 0/i)
      .returnsAffected(0);
    expect(await Notification.markAllAsRead(100)).toBe(false);
  });

  test('delete returns true when row removed', async () => {
    dbMock
      .expectDelete(/DELETE FROM notifications WHERE id = \?/i)
      .returnsAffected(1);
    expect(await Notification.delete(5)).toBe(true);
  });

  test('deleteOldNotifications returns affectedRows', async () => {
    dbMock
      .expectDelete(/DELETE FROM notifications WHERE created_at < DATE_SUB\(NOW\(\), INTERVAL \? DAY\)/i)
      .returnsAffected(3);
    expect(await Notification.deleteOldNotifications(30)).toBe(3);
  });

  test('getUnreadCount returns 0 when row missing', async () => {
    dbMock
      .expectSelect(/SELECT COUNT\(\*\) as unread_count FROM notifications/i)
      .returns([]);
    expect(await Notification.getUnreadCount(100)).toBe(0);
  });

  test('getUnreadCount returns numeric count', async () => {
    dbMock
      .expectSelect(/SELECT COUNT\(\*\) as unread_count FROM notifications/i)
      .returns([{ unread_count: 7 }]);
    expect(await Notification.getUnreadCount(100)).toBe(7);
  });
});
