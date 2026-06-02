/**
 * Socket-level tests for socket/chatSocket.js.
 *
 * These tests use a tiny fake Socket.IO harness instead of binding a real TCP
 * port. That keeps the suite fast while still exercising the production socket
 * middleware and event handlers:
 *   - JWT auth from handshake.auth.token and Authorization header
 *   - invalid tokens rejected before connection
 *   - user/admin room joins
 *   - shipment room permission checks
 *   - message send flow emits to sender, receiver, and admin dashboard
 *   - read receipts deduplicate IDs and emit status updates to message senders
 */
'use strict';

const configureChatSocket = require('../../socket/chatSocket');
const { dbMock } = require('../helpers/db');
const { signToken, tokenForAdmin, tokenForDriver } = require('../helpers/auth');
const { shipmentFactory } = require('../helpers/factories');

const buildHarness = () => {
  const rooms = new Map();
  const io = {
    middleware: null,
    connectionHandler: null,
    use(fn) {
      this.middleware = fn;
      return this;
    },
    on(event, fn) {
      if (event === 'connection') this.connectionHandler = fn;
      return this;
    },
    to(room) {
      if (!rooms.has(room)) rooms.set(room, { emit: jest.fn() });
      return rooms.get(room);
    },
    __room(room) {
      return rooms.get(room);
    },
  };

  configureChatSocket(io);
  return io;
};

const buildSocket = ({ token, header, user } = {}) => {
  const handlers = {};
  const emitted = [];
  return {
    handshake: {
      auth: token ? { token } : {},
      headers: header ? { authorization: header } : {},
    },
    user,
    joined: [],
    disconnected: false,
    on: jest.fn((event, handler) => {
      handlers[event] = handler;
    }),
    join: jest.fn((room) => {
      this?.joined?.push?.(room);
    }),
    emit: jest.fn((event, payload) => {
      emitted.push({ event, payload });
    }),
    disconnect: jest.fn(() => {
      this.disconnected = true;
    }),
    __handlers: handlers,
    __emitted: emitted,
  };
};

const connect = (io, socket) => {
  io.connectionHandler(socket);
  return socket;
};

describe('chatSocket authentication middleware', () => {
  test('rejects sockets with no token', () => {
    const io = buildHarness();
    const next = jest.fn();
    io.middleware(buildSocket(), next);
    expect(next).toHaveBeenCalledWith(expect.any(Error));
    expect(next.mock.calls[0][0].message).toBe('Unauthorized');
  });

  test('rejects malformed JWT tokens', () => {
    const io = buildHarness();
    const next = jest.fn();
    io.middleware(buildSocket({ token: 'not-a-jwt' }), next);
    expect(next).toHaveBeenCalledWith(expect.any(Error));
  });

  test('accepts handshake.auth token and attaches socket.user', () => {
    const io = buildHarness();
    const socket = buildSocket({ token: tokenForDriver(100) });
    const next = jest.fn();
    io.middleware(socket, next);
    expect(next).toHaveBeenCalledWith();
    expect(socket.user).toMatchObject({ id: 100, role: 'driver' });
  });

  test('accepts Bearer token from authorization header', () => {
    const io = buildHarness();
    const socket = buildSocket({ header: `Bearer ${tokenForAdmin(1)}` });
    const next = jest.fn();
    io.middleware(socket, next);
    expect(next).toHaveBeenCalledWith();
    expect(socket.user.role).toBe('admin');
  });
});

describe('chatSocket connection rooms', () => {
  test('disconnects if decoded token has no positive integer id', () => {
    const io = buildHarness();
    const socket = buildSocket({
      user: { id: 0, role: 'driver' },
    });
    connect(io, socket);
    expect(socket.disconnect).toHaveBeenCalledWith(true);
  });

  test('joins the user room and admin dashboard room for admins', () => {
    const io = buildHarness();
    const socket = buildSocket({ user: { id: 1, role: 'admin' } });
    connect(io, socket);
    expect(socket.join).toHaveBeenCalledWith('user:1');
    expect(socket.join).toHaveBeenCalledWith('admin:dashboard');
  });
});

describe('chat:joinShipment', () => {
  test('rejects invalid shipment ids', async () => {
    const io = buildHarness();
    const socket = connect(io, buildSocket({ user: { id: 100, role: 'driver' } }));
    const ack = jest.fn();

    await socket.__handlers['chat:joinShipment']({ shipmentId: 'bad' }, ack);

    expect(ack).toHaveBeenCalledWith({ ok: false, message: 'Invalid shipmentId' });
    expect(socket.emit).toHaveBeenCalledWith('chat:error', { message: 'Invalid shipmentId' });
  });

  test('rejects non-participants', async () => {
    const io = buildHarness();
    const socket = connect(io, buildSocket({ user: { id: 999, role: 'driver' } }));
    dbMock.expectSelect(/FROM shipments s/i).returns([
      shipmentFactory({ id: 1000, shipper_id: 200, driver_id: 100, status: 'assigned' }),
    ]);
    const ack = jest.fn();

    await socket.__handlers['chat:joinShipment']({ shipmentId: 1000 }, ack);

    expect(ack).toHaveBeenCalledWith({ ok: false, message: 'Forbidden' });
    expect(socket.emit).toHaveBeenCalledWith('chat:error', { message: 'Forbidden' });
  });

  test('joins shipment room for a participant', async () => {
    const io = buildHarness();
    const socket = connect(io, buildSocket({ user: { id: 100, role: 'driver' } }));
    dbMock.expectSelect(/FROM shipments s/i).returns([
      shipmentFactory({ id: 1000, shipper_id: 200, driver_id: 100, status: 'assigned' }),
    ]);
    const ack = jest.fn();

    await socket.__handlers['chat:joinShipment']({ shipmentId: 1000 }, ack);

    expect(socket.join).toHaveBeenCalledWith('shipment:1000');
    expect(ack).toHaveBeenCalledWith({ ok: true, shipmentId: 1000 });
  });
});

describe('chat:sendMessage', () => {
  test('rejects missing payload values', async () => {
    const io = buildHarness();
    const socket = connect(io, buildSocket({ user: { id: 100, role: 'driver' } }));
    const ack = jest.fn();

    await socket.__handlers['chat:sendMessage']({ shipmentId: 1000 }, ack);

    expect(ack).toHaveBeenCalledWith({ ok: false, message: 'Invalid message payload' });
  });

  test('creates message and emits to sender, receiver, and admin dashboard', async () => {
    const io = buildHarness();
    const socket = connect(io, buildSocket({ user: { id: 100, role: 'driver' } }));
    const shipment = shipmentFactory({
      id: 1000,
      shipper_id: 200,
      driver_id: 100,
      status: 'assigned',
    });

    dbMock.expectSelect(/FROM shipments s/i).returns([shipment]);
    dbMock.expectSelect(/FROM shipments\s+WHERE/i).returns([]);
    dbMock.expectInsert(/INSERT INTO messages/i).returnsInsert(9001);
    dbMock.expectSelect(/FROM messages m/i).returns([
      {
        id: 9001,
        shipment_id: 1000,
        sender_id: 100,
        receiver_id: 200,
        message_type: 'text',
        message: 'مرحبا',
        media_key: null,
        thumbnail_key: null,
        sender_profile_image_key: null,
      },
    ]);

    const ack = jest.fn();
    await socket.__handlers['chat:sendMessage'](
      {
        shipmentId: 1000,
        receiverId: 200,
        message: '  مرحبا  ',
        clientMessageId: 'client-1',
      },
      ack
    );

    expect(ack).toHaveBeenCalledWith(
      expect.objectContaining({
        ok: true,
        clientMessageId: 'client-1',
        message: expect.objectContaining({ id: 9001, message: 'مرحبا' }),
      })
    );
    expect(io.__room('user:100').emit).toHaveBeenCalledWith(
      'chat:messageSent',
      expect.objectContaining({ clientMessageId: 'client-1' })
    );
    expect(io.__room('user:200').emit).toHaveBeenCalledWith(
      'chat:newMessage',
      expect.objectContaining({ message: expect.objectContaining({ id: 9001 }) })
    );
    const { emitAdminDashboardIo } = require('../../utils/adminRealtime');
    expect(emitAdminDashboardIo).toHaveBeenCalledWith(
      io,
      'chat.message',
      expect.objectContaining({
        shipmentId: 1000,
        senderId: 100,
        receiverId: 200,
        messageId: 9001,
      })
    );
  });
});

describe('chat:joinShipment error paths', () => {
  test('emits Unable to join chat when underlying lookup throws', async () => {
    const io = buildHarness();
    const socket = connect(io, buildSocket({ user: { id: 100, role: 'driver' } }));
    dbMock.expectSelect(/FROM shipments s/i).rejectsWith(new Error('boom'));
    const ack = jest.fn();
    await socket.__handlers['chat:joinShipment']({ shipmentId: 5 }, ack);
    expect(ack).toHaveBeenCalledWith({ ok: false, message: 'Unable to join chat' });
    expect(socket.emit).toHaveBeenCalledWith('chat:error', { message: 'Unable to join chat' });
  });
});

describe('chat:sendMessage error paths', () => {
  test('rejects when validation reports a status code', async () => {
    const io = buildHarness();
    const socket = connect(io, buildSocket({ user: { id: 100, role: 'driver' } }));
    // No active/assigned shipment for these users -> validation returns a status.
    dbMock.expectSelect(/FROM shipments s/i).returns([]);
    dbMock.expectSelect(/FROM shipments\s+WHERE/i).returns([]);
    const ack = jest.fn();
    await socket.__handlers['chat:sendMessage'](
      { shipmentId: 1000, receiverId: 200, message: 'hi' },
      ack,
    );
    expect(ack).toHaveBeenCalledWith(
      expect.objectContaining({ ok: false }),
    );
    expect(socket.emit).toHaveBeenCalledWith(
      'chat:error',
      expect.objectContaining({ message: expect.any(String) }),
    );
  });

  test('emits Unable to send message when persistence throws', async () => {
    const io = buildHarness();
    const socket = connect(io, buildSocket({ user: { id: 100, role: 'driver' } }));
    dbMock.expectSelect(/FROM shipments s/i).rejectsWith(new Error('db-down'));
    const ack = jest.fn();
    await socket.__handlers['chat:sendMessage'](
      { shipmentId: 1000, receiverId: 200, message: 'hi' },
      ack,
    );
    expect(ack).toHaveBeenCalledWith({ ok: false, message: 'Unable to send message' });
    expect(socket.emit).toHaveBeenCalledWith(
      'chat:error',
      { message: 'Unable to send message' },
    );
  });
});

describe('chat:markDelivered', () => {
  test('rejects invalid shipment id', async () => {
    const io = buildHarness();
    const socket = connect(io, buildSocket({ user: { id: 100, role: 'driver' } }));
    const ack = jest.fn();
    await socket.__handlers['chat:markDelivered']({}, ack);
    expect(ack).toHaveBeenCalledWith({ ok: false, message: 'Invalid shipmentId' });
    expect(socket.emit).toHaveBeenCalledWith('chat:error', { message: 'Invalid shipmentId' });
  });

  test('rejects users without chat access (forbidden)', async () => {
    const io = buildHarness();
    const socket = connect(io, buildSocket({ user: { id: 999, role: 'driver' } }));
    dbMock.expectSelect(/FROM shipments s/i).returns([
      shipmentFactory({ id: 1, shipper_id: 1, driver_id: 2, status: 'assigned' }),
    ]);
    const ack = jest.fn();
    await socket.__handlers['chat:markDelivered']({ shipmentId: 1 }, ack);
    expect(ack).toHaveBeenCalledWith({ ok: false, message: 'Forbidden' });
  });

  test('marks messages delivered and emits chat:statusUpdated to senders', async () => {
    const io = buildHarness();
    const socket = connect(io, buildSocket({ user: { id: 200, role: 'shipper' } }));
    dbMock.expectSelect(/FROM shipments s/i).returns([
      shipmentFactory({ id: 1, shipper_id: 200, driver_id: 100, status: 'assigned' }),
    ]);
    dbMock
      .expectSelect(/FROM messages\s+WHERE shipment_id = \?/i)
      .returns([{ id: 11 }, { id: 12 }]);
    dbMock.expectUpdate(/UPDATE messages\s+SET delivered_at/i).returnsAffected(2);
    dbMock.expectSelect(/FROM messages\s+WHERE id IN/i).returns([
      { id: 11, shipment_id: 1, sender_id: 100, delivered_at: new Date(), read_at: null },
      { id: 12, shipment_id: 1, sender_id: 100, delivered_at: new Date(), read_at: null },
    ]);
    const ack = jest.fn();
    await socket.__handlers['chat:markDelivered'](
      { shipmentId: 1, messageIds: [11, 12, 12, 'bad'] },
      ack,
    );
    expect(ack).toHaveBeenCalledWith(
      expect.objectContaining({ ok: true, updated: 2 }),
    );
    expect(io.__room('user:100').emit).toHaveBeenCalledWith(
      'chat:statusUpdated',
      expect.objectContaining({ shipmentId: 1 }),
    );
  });

  test('emits Unable to mark delivered on internal error', async () => {
    const io = buildHarness();
    const socket = connect(io, buildSocket({ user: { id: 200, role: 'shipper' } }));
    dbMock.expectSelect(/FROM shipments s/i).rejectsWith(new Error('boom'));
    const ack = jest.fn();
    await socket.__handlers['chat:markDelivered']({ shipmentId: 1 }, ack);
    expect(ack).toHaveBeenCalledWith({ ok: false, message: 'Unable to mark delivered' });
  });
});

describe('chat:markRead', () => {
  test('rejects invalid shipment id', async () => {
    const io = buildHarness();
    const socket = connect(io, buildSocket({ user: { id: 200, role: 'shipper' } }));
    const ack = jest.fn();
    await socket.__handlers['chat:markRead']({}, ack);
    expect(ack).toHaveBeenCalledWith({ ok: false, message: 'Invalid shipmentId' });
  });

  test('rejects non-participants', async () => {
    const io = buildHarness();
    const socket = connect(io, buildSocket({ user: { id: 999, role: 'driver' } }));
    dbMock.expectSelect(/FROM shipments s/i).returns([
      shipmentFactory({ id: 1, shipper_id: 1, driver_id: 2, status: 'assigned' }),
    ]);
    const ack = jest.fn();
    await socket.__handlers['chat:markRead']({ shipmentId: 1 }, ack);
    expect(ack).toHaveBeenCalledWith({ ok: false, message: 'Forbidden' });
  });

  test('emits Unable to mark read when DB throws', async () => {
    const io = buildHarness();
    const socket = connect(io, buildSocket({ user: { id: 200, role: 'shipper' } }));
    dbMock.expectSelect(/FROM shipments s/i).rejectsWith(new Error('boom'));
    const ack = jest.fn();
    await socket.__handlers['chat:markRead']({ shipmentId: 1 }, ack);
    expect(ack).toHaveBeenCalledWith({ ok: false, message: 'Unable to mark read' });
  });

  test('deduplicates ids and emits status updates grouped by sender', async () => {
    const io = buildHarness();
    const socket = connect(io, buildSocket({ user: { id: 200, role: 'shipper' } }));

    dbMock.expectSelect(/FROM shipments s/i).returns([
      shipmentFactory({ id: 1000, shipper_id: 200, driver_id: 100, status: 'assigned' }),
    ]);
    dbMock
      .expectSelect(/FROM messages\s+WHERE shipment_id = \?/i)
      .withParams([1000, 200, 1, 2])
      .returns([{ id: 1 }, { id: 2 }]);
    dbMock.expectUpdate(/UPDATE messages\s+SET delivered_at/i).returnsAffected(2);
    dbMock.expectSelect(/FROM messages\s+WHERE id IN/i).returns([
      {
        id: 1,
        shipment_id: 1000,
        sender_id: 100,
        receiver_id: 200,
        delivered_at: new Date(),
        read_at: new Date(),
      },
      {
        id: 2,
        shipment_id: 1000,
        sender_id: 100,
        receiver_id: 200,
        delivered_at: new Date(),
        read_at: new Date(),
      },
    ]);

    const ack = jest.fn();
    await socket.__handlers['chat:markRead'](
      { shipmentId: 1000, messageIds: [1, 2, 2, 'x', -1] },
      ack
    );

    expect(ack).toHaveBeenCalledWith(
      expect.objectContaining({ ok: true, updated: 2 })
    );
    expect(io.__room('user:100').emit).toHaveBeenCalledWith(
      'chat:statusUpdated',
      expect.objectContaining({
        shipmentId: 1000,
        messages: expect.arrayContaining([expect.objectContaining({ id: 1 })]),
      })
    );
  });
});
