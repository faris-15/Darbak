const jwt = require('jsonwebtoken');
const Message = require('../models/Message');
const Shipment = require('../models/Shipment');
const { resolveProfileImage } = require('../services/profileService');
const { generatePresignedUrl } = require('../utils/s3Config');
const {
  allowedChatStatuses,
  hasShipmentChatAccess,
  validateShipmentChatSend,
} = require('../controllers/chatController');

const JWT_SECRET = process.env.JWT_SECRET || 'secret_key';
const { ADMIN_DASHBOARD_ROOM, emitAdminDashboardIo } = require('../utils/adminRealtime');

const parsePositiveInt = (value) => {
  const parsed = Number(value);
  return Number.isInteger(parsed) && parsed > 0 ? parsed : null;
};

const parseMessageIds = (value) =>
  Array.isArray(value)
    ? [...new Set(value.map(parsePositiveInt).filter(Boolean))]
    : [];

const emitError = (socket, message) => {
  socket.emit('chat:error', { message });
};

const ack = (callback, payload) => {
  if (typeof callback === 'function') callback(payload);
};

const enrichMessageImage = async (message) => {
  if (!message) return message;
  return {
    ...message,
    media_url: message.media_key ? await generatePresignedUrl(message.media_key) : null,
    thumbnail_url: message.thumbnail_key ? await generatePresignedUrl(message.thumbnail_key) : null,
    sender_profile_image_url: message.sender_profile_image_key
      ? await resolveProfileImage(message.sender_profile_image_key)
      : null,
  };
};

const emitReceiptUpdates = (io, updates) => {
  if (!updates.length) return;

  const updatesBySender = updates.reduce((acc, update) => {
    const senderId = Number(update.sender_id);
    if (!senderId) return acc;
    if (!acc.has(senderId)) acc.set(senderId, []);
    acc.get(senderId).push(update);
    return acc;
  }, new Map());

  for (const [senderId, senderUpdates] of updatesBySender.entries()) {
    io.to(`user:${senderId}`).emit('chat:statusUpdated', {
      shipmentId: Number(senderUpdates[0].shipment_id),
      messages: senderUpdates,
    });
  }
};

const getTokenFromHandshake = (socket) => {
  const authToken = socket.handshake.auth?.token;
  if (authToken) return authToken;

  const header = socket.handshake.headers?.authorization || '';
  return header.startsWith('Bearer ') ? header.slice(7) : null;
};

const configureChatSocket = (io) => {
  io.use((socket, next) => {
    const token = getTokenFromHandshake(socket);
    if (!token) return next(new Error('Unauthorized'));

    try {
      socket.user = jwt.verify(token, JWT_SECRET);
      return next();
    } catch (_) {
      return next(new Error('Unauthorized'));
    }
  });

  io.on('connection', (socket) => {
    const userId = parsePositiveInt(socket.user?.id);
    if (!userId) {
      socket.disconnect(true);
      return;
    }

    socket.join(`user:${userId}`);

    if (String(socket.user?.role || '').toLowerCase() === 'admin') {
      socket.join(ADMIN_DASHBOARD_ROOM);
    }

    socket.on('chat:joinShipment', async (payload = {}, callback) => {
      try {
        const shipmentId = parsePositiveInt(payload.shipmentId);
        if (!shipmentId) {
          ack(callback, { ok: false, message: 'Invalid shipmentId' });
          return emitError(socket, 'Invalid shipmentId');
        }

        const shipment = await Shipment.findById(shipmentId);
        if (!shipment || !hasShipmentChatAccess(shipment, userId)) {
          ack(callback, { ok: false, message: 'Forbidden' });
          return emitError(socket, 'Forbidden');
        }

        socket.join(`shipment:${shipmentId}`);
        return ack(callback, { ok: true, shipmentId });
      } catch (error) {
        console.error('[chat:joinShipment] Error:', error);
        ack(callback, { ok: false, message: 'Unable to join chat' });
        return emitError(socket, 'Unable to join chat');
      }
    });

    socket.on('chat:sendMessage', async (payload = {}, callback) => {
      try {
        const shipmentId = parsePositiveInt(payload.shipmentId);
        const receiverId = parsePositiveInt(payload.receiverId);
        const text = payload.message?.toString().trim();
        const clientMessageId = payload.clientMessageId?.toString();

        if (!shipmentId || !receiverId || !text) {
          ack(callback, { ok: false, message: 'Invalid message payload' });
          return emitError(socket, 'Invalid message payload');
        }

        const validation = await validateShipmentChatSend({
          shipmentId,
          senderId: userId,
          receiverId,
        });
        if (validation.status) {
          ack(callback, { ok: false, message: validation.message });
          return emitError(socket, validation.message);
        }

        const created = await Message.create({
          shipmentId: Number(validation.shipment.id),
          senderId: userId,
          receiverId,
          messageType: 'text',
          message: text,
        });
        const message = await enrichMessageImage((await Message.findById(created.id)) || created);

        const sentPayload = { clientMessageId, message };
        io.to(`user:${userId}`).emit('chat:messageSent', sentPayload);
        io.to(`user:${receiverId}`).emit('chat:newMessage', { message });
        emitAdminDashboardIo(io, 'chat.message', {
          shipmentId,
          senderId: userId,
          receiverId,
          messageId: message?.id,
        });
        ack(callback, { ok: true, ...sentPayload });
      } catch (error) {
        console.error('[chat:sendMessage] Error:', error);
        ack(callback, { ok: false, message: 'Unable to send message' });
        emitError(socket, 'Unable to send message');
      }
    });

    socket.on('chat:markDelivered', async (payload = {}, callback) => {
      try {
        const shipmentId = parsePositiveInt(payload.shipmentId);
        if (!shipmentId) {
          ack(callback, { ok: false, message: 'Invalid shipmentId' });
          return emitError(socket, 'Invalid shipmentId');
        }

        const shipment = await Shipment.findById(shipmentId);
        if (!shipment || !hasShipmentChatAccess(shipment, userId)) {
          ack(callback, { ok: false, message: 'Forbidden' });
          return emitError(socket, 'Forbidden');
        }

        const updates = await Message.markDelivered({
          shipmentId,
          receiverId: userId,
          messageIds: parseMessageIds(payload.messageIds),
        });
        emitReceiptUpdates(io, updates);
        ack(callback, { ok: true, updated: updates.length, messages: updates });
      } catch (error) {
        console.error('[chat:markDelivered] Error:', error);
        ack(callback, { ok: false, message: 'Unable to mark delivered' });
        emitError(socket, 'Unable to mark delivered');
      }
    });

    socket.on('chat:markRead', async (payload = {}, callback) => {
      try {
        const shipmentId = parsePositiveInt(payload.shipmentId);
        if (!shipmentId) {
          ack(callback, { ok: false, message: 'Invalid shipmentId' });
          return emitError(socket, 'Invalid shipmentId');
        }

        const shipment = await Shipment.findById(shipmentId);
        if (!shipment || !hasShipmentChatAccess(shipment, userId)) {
          ack(callback, { ok: false, message: 'Forbidden' });
          return emitError(socket, 'Forbidden');
        }

        const updates = await Message.markRead({
          shipmentId,
          receiverId: userId,
          messageIds: parseMessageIds(payload.messageIds),
        });
        emitReceiptUpdates(io, updates);
        ack(callback, { ok: true, updated: updates.length, messages: updates });
      } catch (error) {
        console.error('[chat:markRead] Error:', error);
        ack(callback, { ok: false, message: 'Unable to mark read' });
        emitError(socket, 'Unable to mark read');
      }
    });
  });
};

module.exports = configureChatSocket;
