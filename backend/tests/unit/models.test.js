/**
 * Unit tests for the lowest-coverage Sequelize-style models.
 *
 * These hit the real model SQL paths (via the dbMock pool) and the helper
 * code around them (search filters, schema introspection, transactions).
 */
'use strict';

const { dbMock } = require('../helpers/db');

describe('models/Wallet', () => {
  const Wallet = require('../../models/Wallet');

  test('createForUser inserts and returns the wallet shell', async () => {
    dbMock.expectInsert(/INSERT INTO wallets/i).returnsInsert(123);
    await expect(Wallet.createForUser(42)).resolves.toEqual({
      id: 123,
      user_id: 42,
      current_balance: 0,
    });
  });

  test('getByUserId returns the first row', async () => {
    dbMock
      .expectSelect(/SELECT \* FROM wallets WHERE user_id = \?/i)
      .returns([{ id: 1, user_id: 7, current_balance: '15.50' }]);
    await expect(Wallet.getByUserId(7)).resolves.toEqual({
      id: 1,
      user_id: 7,
      current_balance: '15.50',
    });
  });

  test('getByUserId returns undefined when wallet absent', async () => {
    dbMock.expectSelect(/SELECT \* FROM wallets/i).returns([]);
    await expect(Wallet.getByUserId(99)).resolves.toBeUndefined();
  });

  test('adjustBalance returns true when affectedRows > 0', async () => {
    dbMock.expectUpdate(/UPDATE wallets SET current_balance = current_balance \+ \?/i).returnsAffected(1);
    await expect(Wallet.adjustBalance(7, 25.5)).resolves.toBe(true);
  });

  test('adjustBalance returns false when affectedRows === 0', async () => {
    dbMock.expectUpdate(/UPDATE wallets/i).returnsAffected(0);
    await expect(Wallet.adjustBalance(7, 25.5)).resolves.toBe(false);
  });
});

describe('models/ComplianceDocument', () => {
  const ComplianceDocument = require('../../models/ComplianceDocument');

  test('create with full S3 URL strips bucket prefix from document_url', async () => {
    dbMock
      .expectInsert(/INSERT INTO compliance_documents/i)
      .withParams([
        1,
        null,
        'license',
        'docs/license-1.pdf',
        '2030-01-01',
        '2020-01-01',
      ])
      .returnsInsert(99);

    await expect(
      ComplianceDocument.create({
        user_id: 1,
        document_type: 'license',
        document_url: 'http://minio:9000/darbak/docs/license-1.pdf',
        expiry_date: '2030-01-01',
        issue_date: '2020-01-01',
      }),
    ).resolves.toBe(99);
  });

  test('create with raw key passes it through unchanged', async () => {
    dbMock
      .expectInsert(/INSERT INTO compliance_documents/i)
      .withParams([5, null, 'cr', 'raw/key.pdf', undefined, undefined])
      .returnsInsert(100);

    await expect(
      ComplianceDocument.create({
        user_id: 5,
        document_type: 'cr',
        document_url: 'raw/key.pdf',
      }),
    ).resolves.toBe(100);
  });

  test('create with truck_id triggers schema ensurer', async () => {
    dbMock
      .expectInsert(/INSERT INTO compliance_documents/i)
      .returnsInsert(101);

    await expect(
      ComplianceDocument.create({
        user_id: 1,
        truck_id: 9,
        document_type: 'insurance',
        document_url: 'k.pdf',
      }),
    ).resolves.toBe(101);
  });

  test('create swallows malformed URL but still inserts (catch branch)', async () => {
    const spy = jest.spyOn(console, 'error').mockImplementation(() => {});
    dbMock
      .expectInsert(/INSERT INTO compliance_documents/i)
      .returnsInsert(200);
    await expect(
      ComplianceDocument.create({
        user_id: 9,
        document_type: 'license',
        document_url: 'http://[invalid',
      }),
    ).resolves.toBe(200);
    spy.mockRestore();
  });

  test('findByUserId returns the rows', async () => {
    dbMock
      .expectSelect(/SELECT \* FROM compliance_documents WHERE user_id = \?/i)
      .returns([{ document_id: 1 }, { document_id: 2 }]);
    await expect(ComplianceDocument.findByUserId(1)).resolves.toHaveLength(2);
  });

  test('findLatestByUserIdAndType returns first row or null', async () => {
    dbMock.expectSelect(/WHERE user_id = \? AND document_type = \?/i).returns([
      { document_id: 5, document_type: 'license' },
    ]);
    await expect(
      ComplianceDocument.findLatestByUserIdAndType(1, 'license'),
    ).resolves.toEqual({ document_id: 5, document_type: 'license' });

    dbMock.expectSelect(/WHERE user_id = \? AND document_type = \?/i).returns([]);
    await expect(
      ComplianceDocument.findLatestByUserIdAndType(1, 'cr'),
    ).resolves.toBeNull();
  });

  test('findLatestByTruckIdAndType returns the doc or null', async () => {
    dbMock
      .expectSelect(/WHERE truck_id = \? AND document_type = \?/i)
      .returns([{ document_id: 11 }]);
    await expect(
      ComplianceDocument.findLatestByTruckIdAndType(3, 'insurance'),
    ).resolves.toEqual({ document_id: 11 });

    dbMock
      .expectSelect(/WHERE truck_id = \? AND document_type = \?/i)
      .returns([]);
    await expect(
      ComplianceDocument.findLatestByTruckIdAndType(4, 'insurance'),
    ).resolves.toBeNull();
  });

  test('updateStatus translates verified → 1 and !verified → 0', async () => {
    dbMock
      .expectUpdate(/UPDATE compliance_documents/i)
      .withParams([1, 7, 'ok', 12])
      .returnsAffected(1);
    await expect(
      ComplianceDocument.updateStatus(12, 'verified', 7, 'ok'),
    ).resolves.toBe(true);

    dbMock
      .expectUpdate(/UPDATE compliance_documents/i)
      .withParams([0, 7, null, 13])
      .returnsAffected(0);
    await expect(
      ComplianceDocument.updateStatus(13, 'rejected', 7),
    ).resolves.toBe(false);
  });

  test('getPending returns admin queue rows', async () => {
    dbMock
      .expectSelect(/FROM compliance_documents cd[\s\S]+JOIN users u ON cd.user_id = u.id[\s\S]+is_verified = 0/i)
      .returns([
        { document_id: 1, full_name: 'A', email: 'a@x.io' },
      ]);
    await expect(ComplianceDocument.getPending()).resolves.toHaveLength(1);
  });
});

describe('models/Conversation', () => {
  const Conversation = require('../../models/Conversation');

  // Helpers: the ensureConversationSchema runs INFORMATION_SCHEMA probes.
  // Setup.js routes those globally — we just need a TABLES route here.
  beforeEach(() => {
    dbMock.route(/FROM INFORMATION_SCHEMA\.TABLES/i, () => [
      [{ count: 1 }],
      { fieldCount: 0 },
    ]);
    dbMock.route(/CREATE TABLE IF NOT EXISTS conversation_participants/i, () => [
      { affectedRows: 0 },
      {},
    ]);
  });

  test('create inserts the row and returns the metadata payload', async () => {
    dbMock.expectInsert(/INSERT INTO conversations/i).returnsInsert(50);
    await expect(
      Conversation.create({
        shipmentId: 1,
        senderId: 2,
        receiverId: 3,
        message: 'hi',
      }),
    ).resolves.toEqual({
      id: 50,
      shipmentId: 1,
      senderId: 2,
      receiverId: 3,
      message: 'hi',
    });
  });

  test('findByShipment lists conversations ordered by created_at', async () => {
    dbMock
      .expectSelect(/SELECT \* FROM conversations WHERE shipment_id = \?/i)
      .returns([{ id: 1 }, { id: 2 }]);
    await expect(Conversation.findByShipment(7)).resolves.toHaveLength(2);
  });

  test('deleteByShipment returns the affected rows count', async () => {
    dbMock
      .expectDelete(/DELETE FROM conversations WHERE shipment_id = \?/i)
      .returnsAffected(3);
    await expect(Conversation.deleteByShipment(7)).resolves.toBe(3);
  });

  test('findDirectByUsers returns the matching conversation_id or null', async () => {
    dbMock.expectSelect(/conversation_participants cp/i).returns([
      { conversation_id: 21 },
    ]);
    await expect(Conversation.findDirectByUsers(1, 2)).resolves.toBe(21);

    dbMock.expectSelect(/conversation_participants cp/i).returns([]);
    await expect(Conversation.findDirectByUsers(1, 9)).resolves.toBeNull();
  });

  test('getOrCreateDirect creates conversation when none exists', async () => {
    dbMock.expectSelect(/SELECT id AS conversation_id[\s\S]+conversation_key = \?/i).returns([]);
    dbMock.expectInsert(/INSERT INTO conversations/i).returnsInsert(55);
    dbMock.expectInsert(/INSERT INTO conversation_participants/i).returnsInsert(1);

    await expect(
      Conversation.getOrCreateDirect({ senderId: 4, receiverId: 1 }),
    ).resolves.toEqual({ conversation_id: 55, created: true });
    expect(dbMock.transactionEvents.slice(-2)).toEqual(
      expect.arrayContaining(['commit']),
    );
  });

  test('getOrCreateDirect returns existing conversation without inserting', async () => {
    dbMock
      .expectSelect(/SELECT id AS conversation_id[\s\S]+conversation_key = \?/i)
      .returns([{ conversation_id: 77 }]);

    await expect(
      Conversation.getOrCreateDirect({ senderId: 7, receiverId: 4 }),
    ).resolves.toEqual({ conversation_id: 77, created: false });
  });

  test('getOrCreateDirect handles ER_DUP_ENTRY race by re-fetching', async () => {
    dbMock
      .expectSelect(/SELECT id AS conversation_id[\s\S]+conversation_key = \?/i)
      .returns([]);
    const dup = new Error('dup');
    dup.code = 'ER_DUP_ENTRY';
    dbMock.expectInsert(/INSERT INTO conversations/i).rejectsWith(dup);
    dbMock
      .expectSelect(/SELECT id AS conversation_id[\s\S]+conversation_key = \?/i)
      .returns([{ conversation_id: 81 }]);

    await expect(
      Conversation.getOrCreateDirect({ senderId: 3, receiverId: 2 }),
    ).resolves.toEqual({ conversation_id: 81, created: false });
  });

  test('getOrCreateDirect re-throws non-duplicate errors', async () => {
    dbMock
      .expectSelect(/SELECT id AS conversation_id[\s\S]+conversation_key = \?/i)
      .returns([]);
    dbMock.expectInsert(/INSERT INTO conversations/i).rejectsWith(new Error('boom'));

    await expect(
      Conversation.getOrCreateDirect({ senderId: 3, receiverId: 2 }),
    ).rejects.toThrow('boom');
  });
});

describe('models/User', () => {
  const User = require('../../models/User');

  test('create returns the inserted user payload with default role driver', async () => {
    dbMock.expectInsert(/INSERT INTO users/i).returnsInsert(5);
    const u = await User.create({
      fullName: 'Sam',
      email: 'sam@x.io',
      phone: '00966500',
      password: 'hash',
    });
    expect(u).toMatchObject({
      id: 5,
      full_name: 'Sam',
      role: 'driver',
      is_active: 1,
      verification_status: 'pending',
    });
  });

  test('findByPhoneOrEmail returns first matching user', async () => {
    dbMock
      .expectSelect(/SELECT \* FROM users WHERE phone = \? OR email = \?/i)
      .returns([{ id: 1, email: 'x@x' }]);
    await expect(User.findByPhoneOrEmail('x@x')).resolves.toEqual({
      id: 1,
      email: 'x@x',
    });
  });

  test('findByEmail returns first user (LOWER lookup)', async () => {
    dbMock
      .expectSelect(/SELECT \* FROM users WHERE LOWER\(email\) = LOWER\(\?\) LIMIT 1/i)
      .returns([{ id: 2 }]);
    await expect(User.findByEmail('Sam@X.io')).resolves.toEqual({ id: 2 });
  });

  test('existsByPhone returns true when rows present', async () => {
    dbMock
      .expectSelect(/SELECT id FROM users WHERE phone = \? LIMIT 1/i)
      .returns([{ id: 1 }]);
    await expect(User.existsByPhone('00966500')).resolves.toBe(true);
  });

  test('existsByPhone returns false on empty result', async () => {
    dbMock.expectSelect(/SELECT id FROM users WHERE phone = \?/i).returns([]);
    await expect(User.existsByPhone('00966500')).resolves.toBe(false);
  });

  test('existsByEmail compares case-insensitively', async () => {
    dbMock
      .expectSelect(/SELECT id FROM users WHERE LOWER\(email\) = LOWER\(\?\) LIMIT 1/i)
      .returns([{ id: 7 }]);
    await expect(User.existsByEmail('Sam@X.io')).resolves.toBe(true);
  });

  test('findById returns first row or undefined', async () => {
    dbMock
      .expectSelect(/SELECT \* FROM users WHERE id = \?/i)
      .returns([{ id: 5 }]);
    await expect(User.findById(5)).resolves.toEqual({ id: 5 });

    dbMock.expectSelect(/SELECT \* FROM users WHERE id = \?/i).returns([]);
    await expect(User.findById(999)).resolves.toBeUndefined();
  });

  test('getFullNamesByIds returns empty when ids list is empty or invalid', async () => {
    await expect(User.getFullNamesByIds([])).resolves.toEqual({});
    await expect(User.getFullNamesByIds(undefined)).resolves.toEqual({});
    await expect(User.getFullNamesByIds([null, 'x', 0, -1])).resolves.toEqual({});
  });

  test('getFullNamesByIds builds placeholder query and maps results', async () => {
    dbMock
      .expectSelect(/SELECT id, full_name FROM users WHERE id IN \(\?,\?,\?\)/i)
      .withParams([1, 2, 3])
      .returns([
        { id: 1, full_name: 'A' },
        { id: 2, full_name: 'B' },
      ]);
    await expect(
      User.getFullNamesByIds([1, 2, 2, 3, '3', NaN]),
    ).resolves.toEqual({ 1: 'A', 2: 'B' });
  });

  test('updateProfileFields returns true when affectedRows > 0', async () => {
    dbMock.expectUpdate(/UPDATE users SET full_name = \?/i).returnsAffected(1);
    await expect(
      User.updateProfileFields(1, { fullName: 'N', email: 'e@x', phone: '0', licenseNo: null, commercialNo: null }),
    ).resolves.toBe(true);
  });

  test('updateProfileImage stores the key and returns boolean', async () => {
    dbMock
      .expectUpdate(/UPDATE users SET profile_image_url = \?/i)
      .withParams(['profile/1/x.jpg', 1])
      .returnsAffected(1);
    await expect(
      User.updateProfileImage(1, 'profile/1/x.jpg'),
    ).resolves.toBe(true);
  });

  test('getPendingVerifications returns list', async () => {
    dbMock
      .expectSelect(/WHERE verification_status = \?/i)
      .returns([{ id: 1 }]);
    await expect(User.getPendingVerifications()).resolves.toHaveLength(1);
  });

  test('updateVerificationStatus and updateActiveFlag work with boolean coercion', async () => {
    dbMock.expectUpdate(/UPDATE users SET verification_status = \?/i).returnsAffected(1);
    await expect(User.updateVerificationStatus(1, 'verified')).resolves.toBe(true);

    dbMock
      .expectUpdate(/UPDATE users SET is_active = \?/i)
      .withParams([1, 1])
      .returnsAffected(1);
    await expect(User.updateActiveFlag(1, true)).resolves.toBe(true);

    dbMock
      .expectUpdate(/UPDATE users SET is_active = \?/i)
      .withParams([0, 1])
      .returnsAffected(1);
    await expect(User.updateActiveFlag(1, false)).resolves.toBe(true);
  });
});

describe('models/Bid', () => {
  const Bid = require('../../models/Bid');

  test('create returns the inserted bid metadata', async () => {
    dbMock.expectInsert(/INSERT INTO bids/i).returnsInsert(11);
    await expect(
      Bid.create({ shipmentId: 1, driverId: 2, bidAmount: 250, estimatedDays: 3 }),
    ).resolves.toEqual({
      id: 11,
      shipmentId: 1,
      driverId: 2,
      bid_amount: 250,
      estimated_days: 3,
    });
  });

  test('findByShipment returns rows in ascending bid_amount order', async () => {
    dbMock
      .expectSelect(/SELECT \* FROM bids WHERE shipment_id = \? ORDER BY bid_amount ASC/i)
      .returns([{ id: 1, bid_amount: 100 }, { id: 2, bid_amount: 120 }]);
    const rows = await Bid.findByShipment(1);
    expect(rows).toHaveLength(2);
  });

  test('findById returns the first row or undefined', async () => {
    dbMock.expectSelect(/SELECT \* FROM bids WHERE id = \?/i).returns([{ id: 5 }]);
    await expect(Bid.findById(5)).resolves.toEqual({ id: 5 });

    dbMock.expectSelect(/SELECT \* FROM bids WHERE id = \?/i).returns([]);
    await expect(Bid.findById(99)).resolves.toBeUndefined();
  });

  test('expirePendingBidsPastAuctionEnd returns affectedRows count', async () => {
    dbMock
      .expectUpdate(/UPDATE bids b\s+INNER JOIN shipments s/i)
      .returnsAffected(3);
    await expect(Bid.expirePendingBidsPastAuctionEnd()).resolves.toBe(3);
  });

  test('findActiveParticipationForDriver respects excludeShipmentId', async () => {
    dbMock
      .expectSelect(/AND b\.shipment_id <> \?[\s\S]+LIMIT 1/i)
      .withParams([5, 99])
      .returns([{ bid_id: 1, shipment_id: 7 }]);
    await expect(
      Bid.findActiveParticipationForDriver(5, { excludeShipmentId: 99 }),
    ).resolves.toEqual({ bid_id: 1, shipment_id: 7 });
  });

  test('findActiveParticipationForDriver without exclusion returns null on empty', async () => {
    dbMock.expectSelect(/LIMIT 1/i).withParams([5]).returns([]);
    await expect(
      Bid.findActiveParticipationForDriver(5),
    ).resolves.toBeNull();
  });

  test('findActiveParticipationOnOtherShipment delegates correctly', async () => {
    dbMock
      .expectSelect(/AND b\.shipment_id <> \?/i)
      .returns([{ bid_id: 9 }]);
    await expect(
      Bid.findActiveParticipationOnOtherShipment(5, 99),
    ).resolves.toEqual({ bid_id: 9 });
  });

  test('setStatus returns boolean from affectedRows', async () => {
    dbMock
      .expectUpdate(/UPDATE bids SET bid_status = \? WHERE id = \?/i)
      .returnsAffected(1);
    await expect(Bid.setStatus(5, 'accepted')).resolves.toBe(true);
  });

  test('rejectOtherBidsForShipment returns affectedRows count', async () => {
    dbMock
      .expectUpdate(/UPDATE bids SET bid_status = \? WHERE shipment_id = \? AND id != \?/i)
      .withParams(['rejected', 1, 5])
      .returnsAffected(2);
    await expect(Bid.rejectOtherBidsForShipment(1, 5)).resolves.toBe(2);
  });

  test('findByShipmentWithDriver joins users + ratings sub-queries', async () => {
    dbMock
      .expectSelect(/FROM bids b\s+LEFT JOIN users u/i)
      .returns([
        {
          id: 1,
          driver_id: 9,
          bid_amount: 100,
          driver_name: 'Driver',
          driver_rating: 4.5,
          rating_count: 8,
        },
      ]);
    await expect(Bid.findByShipmentWithDriver(7)).resolves.toEqual([
      expect.objectContaining({ driver_name: 'Driver', driver_rating: 4.5 }),
    ]);
  });

  test('acceptBid returns true when row updated', async () => {
    dbMock
      .expectUpdate(/UPDATE bids SET bid_status = \? WHERE id = \?/i)
      .withParams(['accepted', 5])
      .returnsAffected(1);
    await expect(Bid.acceptBid(5, 1)).resolves.toBe(true);
  });
});

describe('models/Truck — branch coverage', () => {
  const Truck = require('../../models/Truck');

  test('findActiveByDriverId returns row or null', async () => {
    dbMock
      .expectSelect(/SELECT \* FROM trucks WHERE user_id = \? AND is_active = 1 ORDER BY id DESC LIMIT 1/i)
      .returns([{ id: 3, user_id: 9, is_active: 1 }]);
    await expect(Truck.findActiveByDriverId(9)).resolves.toEqual(
      expect.objectContaining({ id: 3 }),
    );

    dbMock
      .expectSelect(/SELECT \* FROM trucks WHERE user_id = \? AND is_active = 1/i)
      .returns([]);
    await expect(Truck.findActiveByDriverId(99)).resolves.toBeNull();
  });

  test('verifyTruck returns boolean from affectedRows', async () => {
    dbMock
      .expectUpdate(/UPDATE trucks SET verification_status = \?/i)
      .returnsAffected(1);
    await expect(Truck.verifyTruck(1, 'verified')).resolves.toBe(true);
  });

  test('list returns rows', async () => {
    dbMock
      .expectSelect(/SELECT \* FROM trucks ORDER BY created_at DESC/i)
      .returns([{ id: 1 }, { id: 2 }]);
    await expect(Truck.list()).resolves.toHaveLength(2);
  });

  test('listPending returns pending verifications', async () => {
    dbMock
      .expectSelect(/WHERE verification_status = "pending"/i)
      .returns([{ id: 3 }]);
    await expect(Truck.listPending()).resolves.toHaveLength(1);
  });

  test('update rolls back when truck does not exist', async () => {
    dbMock.expectSelect(/SELECT user_id FROM trucks WHERE id = \?/i).returns([]);
    await expect(
      Truck.update(99, { plate_number: 'X', is_active: false }),
    ).resolves.toBe(false);
    expect(dbMock.transactionEvents).toEqual(
      expect.arrayContaining(['begin', 'rollback', 'release']),
    );
  });

  test('update deactivates the user’s other trucks when is_active is true', async () => {
    dbMock
      .expectSelect(/SELECT user_id FROM trucks WHERE id = \?/i)
      .returns([{ user_id: 9 }]);
    dbMock
      .expectUpdate(/UPDATE trucks SET is_active = 0 WHERE user_id = \?/i)
      .returnsAffected(2);
    dbMock
      .expectUpdate(/UPDATE trucks SET[\s\S]+plate_number = \?/i)
      .returnsAffected(1);

    await expect(
      Truck.update(5, {
        plate_number: 'ABC123',
        isthimara_no: 'i',
        truck_type: 'flatbed',
        category: 1,
        axle_count: 2,
        body_type: 'flat',
        payload_capacity: 10,
        max_weight_tons: 12,
        capacity_kg: 12000,
        manufacturing_year: 2020,
        insurance_expiry_date: '2030-01-01',
        is_active: true,
      }),
    ).resolves.toBe(true);
    expect(dbMock.transactionEvents).toEqual(
      expect.arrayContaining(['commit']),
    );
  });

  test('update rolls back and rethrows on update error', async () => {
    dbMock
      .expectSelect(/SELECT user_id FROM trucks/i)
      .returns([{ user_id: 9 }]);
    dbMock
      .expectUpdate(/UPDATE trucks SET[\s\S]+plate_number = \?/i)
      .rejectsWith(new Error('db-fail'));

    await expect(
      Truck.update(5, {
        plate_number: 'A',
        is_active: false,
      }),
    ).rejects.toThrow('db-fail');
    expect(dbMock.transactionEvents).toEqual(
      expect.arrayContaining(['rollback']),
    );
  });

  test('setActiveForDriver returns false when truck not owned by user', async () => {
    dbMock
      .expectSelect(/SELECT id FROM trucks WHERE id = \? AND user_id = \?/i)
      .returns([]);
    await expect(Truck.setActiveForDriver(1, 99)).resolves.toBe(false);
  });

  test('setActiveForDriver activates exclusively the requested truck', async () => {
    dbMock
      .expectSelect(/SELECT id FROM trucks WHERE id = \? AND user_id = \?/i)
      .returns([{ id: 1 }]);
    dbMock
      .expectUpdate(/UPDATE trucks SET is_active = 0 WHERE user_id = \?/i)
      .returnsAffected(1);
    dbMock
      .expectUpdate(/UPDATE trucks SET is_active = 1 WHERE id = \? AND user_id = \?/i)
      .returnsAffected(1);
    await expect(Truck.setActiveForDriver(1, 9)).resolves.toBe(true);
  });

  test('setActiveForDriver rolls back and rethrows on inner failure', async () => {
    dbMock
      .expectSelect(/SELECT id FROM trucks/i)
      .returns([{ id: 1 }]);
    dbMock
      .expectUpdate(/UPDATE trucks SET is_active = 0/i)
      .rejectsWith(new Error('boom'));
    await expect(Truck.setActiveForDriver(1, 9)).rejects.toThrow('boom');
  });
});

describe('models/Shipment — uncovered branches', () => {
  const Shipment = require('../../models/Shipment');

  test('search applies every recognised filter and city OR-clause', async () => {
    dbMock
      .expectSelect(/SELECT s\.\*/)
      .returns([{ id: 1, shipper_id: 9, base_price: 100 }]);

    const data = await Shipment.search({
      filters: {
        shipperId: 9,
        statuses: ['bidding', 'open'],
        pickupCity: 'Riy_a%dh',
        dropoffCity: 'Jed\\dah',
        cargoCategory: 'food',
        city: 'Mecca',
        minPrice: 50,
        maxPrice: 200,
        minWeight: 5,
        maxWeight: 50,
        truckGroup: 'small',
        truckCategory: 'pickup',
        driverTruckGroup: 'small',
        driverMaxCapacityTons: 3.5,
        driverAxleCount: 4,
        driverBodyType: 'flatbed',
      },
    });
    expect(Array.isArray(data)).toBe(true);
    expect(data[0]).toEqual(expect.objectContaining({ suggested_price: 100 }));
  });

  test('search with truckGroup that has no categories falls back to group-only', async () => {
    dbMock
      .expectSelect(/SELECT s\.\*/)
      .returns([{ id: 2, suggested_price: 50, base_price: 50 }]);
    await expect(
      Shipment.search({ filters: { truckGroup: 'nonexistent_group_xyz' } }),
    ).resolves.toEqual([
      expect.objectContaining({ id: 2 }),
    ]);
  });

  test('search uses driverTruckCategory shortcut when given', async () => {
    dbMock.expectSelect(/SELECT s\.\*/).returns([{ id: 3, base_price: 1 }]);
    await expect(
      Shipment.search({ filters: { driverTruckCategory: 'pickup' } }),
    ).resolves.toHaveLength(1);
  });

  test('search with pagination returns data + pagination meta', async () => {
    dbMock.expectSelect(/SELECT COUNT\(\*\) AS total FROM shipments/i).returns([{ total: 42 }]);
    dbMock.expectSelect(/SELECT s\.\*/).returns([{ id: 4, base_price: 1 }]);
    const out = await Shipment.search({
      pagination: { page: 2, limit: 10 },
    });
    expect(out).toEqual({
      data: [expect.objectContaining({ id: 4 })],
      pagination: { page: 2, limit: 10, total: 42, totalPages: 5 },
    });
  });

  test('list / listForShipper delegate to search', async () => {
    dbMock.expectSelect(/SELECT s\.\*/).returns([{ id: 5, base_price: 1 }]);
    await expect(Shipment.list()).resolves.toHaveLength(1);

    dbMock.expectSelect(/SELECT s\.\*/).returns([{ id: 6, base_price: 1 }]);
    await expect(Shipment.listForShipper(9)).resolves.toHaveLength(1);
  });

  test('findChatShipmentBetweenUsers returns null when no statuses given', async () => {
    await expect(
      Shipment.findChatShipmentBetweenUsers({
        senderId: 1,
        receiverId: 2,
        statuses: [],
      }),
    ).resolves.toBeNull();
  });

  test('findChatShipmentBetweenUsers uses preferredSort when preferredShipmentId provided', async () => {
    dbMock
      .expectSelect(/CASE WHEN id = \? THEN 0 ELSE 1 END/i)
      .returns([{ id: 12, base_price: 1 }]);
    await expect(
      Shipment.findChatShipmentBetweenUsers({
        senderId: 1,
        receiverId: 2,
        preferredShipmentId: 12,
        statuses: ['assigned', 'en_route'],
      }),
    ).resolves.toEqual(expect.objectContaining({ id: 12 }));
  });

  test('countByShipperInStatuses returns 0 when statuses empty', async () => {
    await expect(
      Shipment.countByShipperInStatuses(1, []),
    ).resolves.toBe(0);
  });

  test('countByShipperInStatuses returns cnt from query', async () => {
    dbMock
      .expectSelect(/SELECT COUNT\(\*\) AS cnt FROM shipments/i)
      .returns([{ cnt: 7 }]);
    await expect(
      Shipment.countByShipperInStatuses(2, ['delivered']),
    ).resolves.toBe(7);
  });

  test('listActiveByDriver returns rows with suggested_price', async () => {
    dbMock.expectSelect(/AND status IN \('assigned',/i).returns([
      { id: 1, base_price: 100, suggested_price: null },
    ]);
    await expect(Shipment.listActiveByDriver(3)).resolves.toEqual([
      expect.objectContaining({ suggested_price: 100 }),
    ]);
  });

  test('listByDriverPriority returns rows', async () => {
    dbMock.expectSelect(/status_priority ASC/i).returns([{ id: 1, base_price: 1 }]);
    await expect(Shipment.listByDriverPriority(3)).resolves.toHaveLength(1);
  });

  test('completeDelivery throws when shipment lookup misses', async () => {
    dbMock.expectSelect(/SELECT s\.\*/).returns([]);
    await expect(
      Shipment.completeDelivery({
        shipmentId: 99,
        bidAmount: 100,
        actualDeliveryDate: '2025-01-01',
      }),
    ).rejects.toThrow('Shipment not found');
  });

  test('completeDelivery throws when shipment has no deadline', async () => {
    await expect(
      Shipment.completeDelivery({
        shipmentId: 1,
        bidAmount: 100,
        actualDeliveryDate: '2025-01-01',
        shipment: { id: 1, expected_delivery_date: null, period: null },
      }),
    ).rejects.toThrow('Shipment has no delivery deadline');
  });

  test('completeDelivery computes penalty and updates row', async () => {
    dbMock
      .expectUpdate(/UPDATE shipments SET actual_delivery_date = \?, final_price = \?/i)
      .returnsAffected(1);

    const result = await Shipment.completeDelivery({
      shipmentId: 7,
      bidAmount: 200,
      actualDeliveryDate: new Date('2025-01-10T00:00:00Z'),
      shipment: {
        id: 7,
        expected_delivery_date: new Date('2025-01-01T00:00:00Z'),
      },
    });
    expect(result.success).toBe(true);
    expect(result.final_price).toBeLessThanOrEqual(200);
  });

  test('updateStatus returns boolean', async () => {
    dbMock
      .expectUpdate(/UPDATE shipments SET status = \?/i)
      .returnsAffected(1);
    await expect(Shipment.updateStatus(1, 'en_route')).resolves.toBe(true);
  });

  test('setDeliveryMetadata returns boolean', async () => {
    dbMock
      .expectUpdate(/UPDATE shipments SET actual_delivery_date = \?/i)
      .returnsAffected(1);
    await expect(
      Shipment.setDeliveryMetadata(1, {
        actualDeliveryDate: '2025-01-10',
        podPhotoPath: 'epod/x.jpg',
      }),
    ).resolves.toBe(true);
  });

  test('getDriverStats falls back to zeros when row is empty', async () => {
    dbMock.expectSelect(/SELECT COUNT\(\*\) as completed_trips/i).returns([]);
    await expect(Shipment.getDriverStats(1)).resolves.toEqual({
      completed_trips: 0,
      total_earnings: 0,
    });
  });

  test('getShipperStats returns aggregate', async () => {
    dbMock.expectSelect(/SELECT.+total_shipments.+delivered_shipments.+active_shipments/is).returns([
      { total_shipments: 10, delivered_shipments: 7, active_shipments: 2 },
    ]);
    await expect(Shipment.getShipperStats(1)).resolves.toEqual({
      total_shipments: 10,
      delivered_shipments: 7,
      active_shipments: 2,
    });
  });

  test('assignDriver returns boolean', async () => {
    dbMock
      .expectUpdate(/UPDATE shipments SET driver_id = \?, status = \?/i)
      .returnsAffected(1);
    await expect(Shipment.assignDriver(1, 9)).resolves.toBe(true);
  });
});
