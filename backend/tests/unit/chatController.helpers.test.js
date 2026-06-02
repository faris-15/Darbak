/**
 * Unit tests for the chatController helper functions. We exercise the helpers
 * via the public route handlers and `validateShipmentChatSend` exports plus
 * `emitReceiptUpdates`-style behaviours through `markRead/markDelivered`.
 *
 * These tests focus on the small pure helpers (messagePreview branches,
 * inferMediaMessageType requestedType fallbacks, socket emit dispatchers)
 * that are not reachable from the existing HTTP integration tests.
 */
'use strict';

const path = require('path');

// Load the controller after the suite-wide jest.mock setups in setup.js have
// installed the s3/firebase/mysql shims.
const chatController = require('../../controllers/chatController');

describe('chatController.validateShipmentChatSend — argument branches', () => {
  let Shipment;
  let findByIdSpy;
  let fallbackSpy;

  beforeAll(() => {
    Shipment = require('../../models/Shipment');
  });

  beforeEach(() => {
    findByIdSpy = jest.spyOn(Shipment, 'findById');
    fallbackSpy = jest.spyOn(Shipment, 'findChatShipmentBetweenUsers');
  });

  afterEach(() => {
    findByIdSpy.mockRestore();
    fallbackSpy.mockRestore();
  });

  test('returns 404 when both lookup and fallback miss', async () => {
    findByIdSpy.mockResolvedValueOnce(null);
    fallbackSpy.mockResolvedValueOnce(null);
    const result = await chatController.validateShipmentChatSend({
      shipmentId: 1,
      senderId: 100,
    });
    expect(result.status).toBe(404);
  });

  test('infers receiverId from shipment when sender is shipper', async () => {
    findByIdSpy.mockResolvedValueOnce({
      id: 1,
      shipper_id: 200,
      driver_id: 100,
      status: 'assigned',
    });
    fallbackSpy.mockResolvedValueOnce(null);
    const result = await chatController.validateShipmentChatSend({
      shipmentId: 1,
      senderId: 200,
    });
    expect(result.receiverId).toBe(100);
  });

  test('infers receiverId from shipment when sender is driver', async () => {
    findByIdSpy.mockResolvedValueOnce({
      id: 1,
      shipper_id: 200,
      driver_id: 100,
      status: 'assigned',
    });
    fallbackSpy.mockResolvedValueOnce(null);
    const result = await chatController.validateShipmentChatSend({
      shipmentId: 1,
      senderId: 100,
    });
    expect(result.receiverId).toBe(200);
  });

  test('promotes fallback shipment when primary is in wrong status', async () => {
    findByIdSpy.mockResolvedValueOnce({
      id: 1,
      shipper_id: 200,
      driver_id: 100,
      status: 'pending',
    });
    fallbackSpy.mockResolvedValueOnce({
      id: 2,
      shipper_id: 200,
      driver_id: 100,
      status: 'en_route',
    });
    const result = await chatController.validateShipmentChatSend({
      shipmentId: 1,
      senderId: 100,
    });
    expect(result.shipment?.id).toBe(2);
  });

  test('returns 400 when shipment is found but in non-chat status', async () => {
    findByIdSpy.mockResolvedValueOnce({
      id: 1,
      shipper_id: 200,
      driver_id: 100,
      status: 'pending',
    });
    fallbackSpy.mockResolvedValueOnce(null);
    const result = await chatController.validateShipmentChatSend({
      shipmentId: 1,
      senderId: 200,
    });
    expect(result.status).toBe(400);
  });

  test('returns 403 when sender is neither shipper nor driver on the active shipment', async () => {
    findByIdSpy.mockResolvedValueOnce(null);
    fallbackSpy.mockResolvedValueOnce({
      id: 2,
      shipper_id: 200,
      driver_id: 100,
      status: 'en_route',
    });
    const result = await chatController.validateShipmentChatSend({
      shipmentId: 2,
      senderId: 999,
    });
    expect(result.status).toBe(403);
  });

  test('returns 400 when the active shipment has no counter-party', async () => {
    findByIdSpy.mockResolvedValueOnce(null);
    fallbackSpy.mockResolvedValueOnce({
      id: 2,
      shipper_id: 200,
      driver_id: null,
      status: 'en_route',
    });
    const result = await chatController.validateShipmentChatSend({
      shipmentId: 2,
      senderId: 200,
    });
    expect(result.status).toBe(400);
  });
});

describe('chatController route handlers — socket emit and catch branches', () => {
  // Helpers to construct in-memory Express-like req/res pairs.
  const makeRes = () => {
    const headers = {};
    const r = {
      statusCode: 200,
      body: null,
      headers,
      status(code) {
        r.statusCode = code;
        return r;
      },
      json(payload) {
        r.body = payload;
        return r;
      },
    };
    return r;
  };

  const makeReq = ({ user = { id: 100 }, body = {}, params = {}, file = null, io } = {}) => {
    const ioGetter = io ? jest.fn(() => io) : jest.fn(() => null);
    return {
      user,
      body,
      params,
      file,
      app: { get: ioGetter },
    };
  };

  beforeEach(() => {
    jest.resetModules();
  });

  test('sendShipmentMediaMessage 400 when file missing', async () => {
    const ctrl = require('../../controllers/chatController');
    const req = makeReq({ params: { shipmentId: 9 }, body: { receiverId: 100 } });
    const res = makeRes();
    await ctrl.sendShipmentMediaMessage(req, res);
    expect(res.statusCode).toBe(400);
  });

  test('sendShipmentMediaMessage cleans up S3 when validation rejects', async () => {
    const ctrl = require('../../controllers/chatController');
    const Shipment = require('../../models/Shipment');
    jest.spyOn(Shipment, 'findById').mockResolvedValueOnce(null);
    jest.spyOn(Shipment, 'findChatShipmentBetweenUsers').mockResolvedValueOnce(null);
    const { deleteS3Object } = require('../../utils/s3Config');
    const cleanupSpy = jest.spyOn({ deleteS3Object }, 'deleteS3Object');
    const s3 = require('../../utils/s3Config');
    s3.deleteS3Object.mockClear();

    const req = makeReq({
      params: { shipmentId: 9 },
      body: { receiverId: 100 },
      file: { key: 'media/x.png', mimetype: 'image/png', size: 10, originalname: 'x.png' },
    });
    const res = makeRes();
    await ctrl.sendShipmentMediaMessage(req, res);
    expect(res.statusCode).toBe(404);
    expect(s3.deleteS3Object).toHaveBeenCalledWith('media/x.png');
    cleanupSpy.mockRestore();
  });

  test('sendShipmentMediaMessage 500 catch removes S3 object', async () => {
    const ctrl = require('../../controllers/chatController');
    const Shipment = require('../../models/Shipment');
    const Message = require('../../models/Message');
    jest.spyOn(Shipment, 'findById').mockResolvedValueOnce({
      id: 1,
      shipper_id: 200,
      driver_id: 100,
      status: 'assigned',
    });
    jest.spyOn(Shipment, 'findChatShipmentBetweenUsers').mockResolvedValueOnce({
      id: 1,
      shipper_id: 200,
      driver_id: 100,
      status: 'assigned',
    });
    jest.spyOn(Message, 'create').mockRejectedValueOnce(new Error('boom'));
    const s3 = require('../../utils/s3Config');
    s3.deleteS3Object.mockClear();

    const req = makeReq({
      user: { id: 200 },
      params: { shipmentId: 1 },
      body: { receiverId: 100, messageType: 'video' },
      file: { key: 'media/v.mp4', mimetype: 'video/mp4', size: 99, originalname: 'v.mp4' },
    });
    const res = makeRes();
    await ctrl.sendShipmentMediaMessage(req, res);
    expect(res.statusCode).toBe(500);
    expect(s3.deleteS3Object).toHaveBeenCalledWith('media/v.mp4');
  });

  test('sendShipmentLocationMessage 500 on catch', async () => {
    const ctrl = require('../../controllers/chatController');
    const Shipment = require('../../models/Shipment');
    const Message = require('../../models/Message');
    jest.spyOn(Shipment, 'findById').mockResolvedValueOnce({
      id: 1,
      shipper_id: 200,
      driver_id: 100,
      status: 'assigned',
    });
    jest.spyOn(Shipment, 'findChatShipmentBetweenUsers').mockResolvedValueOnce({
      id: 1,
      shipper_id: 200,
      driver_id: 100,
      status: 'assigned',
    });
    jest.spyOn(Message, 'create').mockRejectedValueOnce(new Error('db down'));
    const req = makeReq({
      user: { id: 200 },
      params: { shipmentId: 1 },
      body: { receiverId: 100, latitude: 24, longitude: 46 },
    });
    const res = makeRes();
    await ctrl.sendShipmentLocationMessage(req, res);
    expect(res.statusCode).toBe(500);
  });

  test('markShipmentMessagesDelivered emits chat:statusUpdated for sender', async () => {
    const ctrl = require('../../controllers/chatController');
    const Shipment = require('../../models/Shipment');
    const Message = require('../../models/Message');
    jest.spyOn(Shipment, 'findById').mockResolvedValueOnce({
      id: 1,
      shipper_id: 200,
      driver_id: 100,
      status: 'assigned',
    });
    jest.spyOn(Message, 'markDelivered').mockResolvedValueOnce([
      { id: 11, sender_id: 200, shipment_id: 1, delivered_at: new Date() },
      { id: 12, sender_id: 200, shipment_id: 1, delivered_at: new Date() },
      // entry with falsy sender_id is dropped silently
      { id: 13, sender_id: 0, shipment_id: 1 },
    ]);
    const emit = jest.fn();
    const io = { to: jest.fn(() => ({ emit })) };
    const req = makeReq({
      user: { id: 100 },
      params: { shipmentId: 1 },
      body: { messageIds: [11, 12, 13] },
      io,
    });
    const res = makeRes();
    await ctrl.markShipmentMessagesDelivered(req, res);
    expect(res.statusCode).toBe(200);
    expect(io.to).toHaveBeenCalledWith('user:200');
    expect(emit).toHaveBeenCalledWith(
      'chat:statusUpdated',
      expect.objectContaining({ shipmentId: 1, messages: expect.any(Array) })
    );
  });

  test('markShipmentMessagesRead no-op when there are no updates', async () => {
    const ctrl = require('../../controllers/chatController');
    const Shipment = require('../../models/Shipment');
    const Message = require('../../models/Message');
    jest.spyOn(Shipment, 'findById').mockResolvedValueOnce({
      id: 1,
      shipper_id: 200,
      driver_id: 100,
      status: 'assigned',
    });
    jest.spyOn(Message, 'markRead').mockResolvedValueOnce([]);
    const req = makeReq({
      user: { id: 100 },
      params: { shipmentId: 1 },
      body: {},
    });
    const res = makeRes();
    await ctrl.markShipmentMessagesRead(req, res);
    expect(res.statusCode).toBe(200);
    expect(res.body.updated).toBe(0);
  });
});
