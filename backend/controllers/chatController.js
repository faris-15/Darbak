const Message = require('../models/Message');
const Shipment = require('../models/Shipment');
const path = require('path');
const { resolveProfileImage } = require('../services/profileService');
const { generatePresignedUrl, deleteS3Object } = require('../utils/s3Config');

const allowedChatStatuses = new Set(['assigned', 'at_pickup', 'en_route', 'at_dropoff', 'delivered']);
const allowedChatStatusList = [...allowedChatStatuses];

const hasShipmentChatAccess = (shipment, userId) =>
  Number(shipment.shipper_id) === Number(userId) || Number(shipment.driver_id) === Number(userId);

const parseMessageIds = (value) =>
  Array.isArray(value)
    ? value
        .map((id) => Number(id))
        .filter((id) => Number.isInteger(id) && id > 0)
    : [];

const parseCoordinate = (value) => {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : null;
};

const inferMediaMessageType = (file, requestedType) => {
  const mimeType = (file?.mimetype || '').toLowerCase();
  const extension = path.extname(file?.originalname || file?.key || '').toLowerCase();
  if (mimeType.startsWith('video/') || ['.mp4', '.mov', '.m4v'].includes(extension)) {
    return 'video';
  }
  if (mimeType.startsWith('image/')) return 'image';
  if (requestedType === 'image' || requestedType === 'video') return requestedType;
  return 'image';
};

const messagePreview = (row) => {
  if (row.media_key || row.message_type === 'image' || row.message_type === 'video') {
    const inferredType = inferMediaMessageType(
      {
        mimetype: row.media_mime_type,
        originalname: row.media_file_name,
        key: row.media_key,
      },
      row.message_type
    );
    if (inferredType === 'video') return 'فيديو';
    if (inferredType === 'image') return 'صورة';
  }
  if (row.message_type === 'image') return 'صورة';
  if (row.message_type === 'video') return 'فيديو';
  if (row.message_type === 'location') return row.location_label || 'موقع';
  return row.message || '';
};

const emitReceiptUpdates = (req, updates) => {
  const io = req.app.get('io');
  if (!io || !updates.length) return;

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

const enrichMessages = async (rows) =>
  Promise.all(
    rows.map(async (row) => ({
      ...row,
      last_preview: row.last_preview ?? messagePreview(row),
      media_url: row.media_key ? await generatePresignedUrl(row.media_key) : null,
      thumbnail_url: row.thumbnail_key ? await generatePresignedUrl(row.thumbnail_key) : null,
      sender_profile_image_url: row.sender_profile_image_key
        ? await resolveProfileImage(row.sender_profile_image_key)
        : null,
    }))
  );

const enrichConversationImages = async (rows) =>
  Promise.all(
    rows.map(async (row) => ({
      ...row,
      other_party_profile_image_url: row.other_party_profile_image_key
        ? await resolveProfileImage(row.other_party_profile_image_key)
        : null,
    }))
  );

const emitChatMessage = (req, message, receiverId, clientMessageId = null) => {
  const io = req.app.get('io');
  if (!io) return;
  io.to(`user:${Number(req.user.id)}`).emit('chat:messageSent', {
    clientMessageId,
    message,
  });
  io.to(`user:${Number(receiverId)}`).emit('chat:newMessage', {
    message,
  });
};

const validateShipmentChatSend = async ({ shipmentId, senderId, receiverId: providedReceiverId }) => {
  const shipment = await Shipment.findById(shipmentId);

  // If receiver not provided, try to infer it from the shipment if it's already assigned
  let effectiveReceiverId = providedReceiverId;
  if (!effectiveReceiverId && shipment) {
    if (Number(shipment.shipper_id) === Number(senderId)) effectiveReceiverId = shipment.driver_id;
    else if (Number(shipment.driver_id) === Number(senderId)) effectiveReceiverId = shipment.shipper_id;
  }

  const fallbackShipment = await Shipment.findChatShipmentBetweenUsers({
    senderId: Number(senderId),
    receiverId: effectiveReceiverId ? Number(effectiveReceiverId) : null,
    preferredShipmentId: Number(shipmentId),
    statuses: allowedChatStatusList,
  });

  if (!shipment && !fallbackShipment) {
    return { status: 404, message: 'الشحنة غير موجودة' };
  }

  // Use the shipment that matches allowed statuses and participation
  let activeShipment = null;
  if (shipment && allowedChatStatuses.has(shipment.status) && hasShipmentChatAccess(shipment, senderId)) {
    activeShipment = shipment;
  } else if (fallbackShipment) {
    activeShipment = fallbackShipment;
  }

  if (!activeShipment) {
    if (shipment && !allowedChatStatuses.has(shipment.status)) {
      console.warn('[validateShipmentChatSend] Rejected by status', {
        shipmentId,
        status: shipment.status,
      });
      return { status: 400, message: 'المحادثة متاحة فقط بعد قبول العرض' };
    }
    return { status: 403, message: 'غير مصرح لك بإرسال رسائل لهذه الشحنة' };
  }

  const isShipper = Number(activeShipment.shipper_id) === Number(senderId);
  const isDriver = Number(activeShipment.driver_id) === Number(senderId);

  if (!isShipper && !isDriver) {
    return { status: 403, message: 'غير مصرح لك بإرسال رسائل لهذه الشحنة' };
  }

  // Identity Mapping: Always derive the receiver from the shipment participants to prevent identity swapping issues
  const receiverId = isShipper ? activeShipment.driver_id : activeShipment.shipper_id;

  if (!receiverId) {
    return { status: 400, message: 'المستقبل غير مرتبط بهذه الشحنة' };
  }

  return { shipment: activeShipment, receiverId };
};

const getShipmentChat = async (req, res) => {
  try {
    const { shipmentId } = req.params;
    const shipment = await Shipment.findById(shipmentId);
    if (!shipment) {
      return res.status(404).json({ message: 'الشحنة غير موجودة' });
    }
    if (!hasShipmentChatAccess(shipment, req.user?.id)) {
      return res.status(403).json({ message: 'غير مصرح لك بهذه المحادثة' });
    }
    const messages = await enrichMessages(await Message.listByShipment(shipmentId));
    return res.json(messages);
  } catch (error) {
    console.error('[getShipmentChat] Error:', error);
    return res.status(500).json({ message: 'خطأ في جلب المحادثة' });
  }
};

const sendShipmentMessage = async (req, res) => {
  try {
    const { shipmentId, receiverId, message } = req.body;
    if (!shipmentId || !message?.toString().trim()) {
      return res.status(400).json({ message: 'بيانات الرسالة غير مكتملة' });
    }
    const validation = await validateShipmentChatSend({
      shipmentId,
      senderId: req.user?.id,
      receiverId,
    });
    if (validation.status) {
      return res.status(validation.status).json({ message: validation.message });
    }

    const created = await Message.create({
      shipmentId: Number(validation.shipment.id),
      senderId: Number(req.user.id),
      receiverId: Number(validation.receiverId),
      messageType: 'text',
      message: message.toString().trim(),
    });
    const row = await Message.findById(created.id);
    const [enriched] = await enrichMessages(row ? [row] : [created]);
    emitChatMessage(req, enriched, validation.receiverId);
    return res.status(201).json(enriched);
  } catch (error) {
    console.error('[sendShipmentMessage] Error:', error);
    return res.status(500).json({ message: 'خطأ في إرسال الرسالة' });
  }
};

const sendShipmentMediaMessage = async (req, res) => {
  try {
    const { shipmentId } = req.params;
    const { receiverId, caption, messageType: requestedMessageType } = req.body;
    const uploadedFile = req.file;
    if (!shipmentId || !uploadedFile?.key) {
      return res.status(400).json({ message: 'بيانات الوسائط غير مكتملة' });
    }

    const validation = await validateShipmentChatSend({
      shipmentId,
      senderId: req.user?.id,
      receiverId,
    });
    if (validation.status) {
      await deleteS3Object(uploadedFile.key).catch(() => {});
      return res.status(validation.status).json({ message: validation.message });
    }

    const mimeType = uploadedFile.mimetype || '';
    const messageType = inferMediaMessageType(uploadedFile, requestedMessageType);
    const created = await Message.create({
      shipmentId: Number(validation.shipment.id),
      senderId: Number(req.user.id),
      receiverId: Number(validation.receiverId),
      messageType,
      message: caption?.toString().trim() || '',
      mediaKey: uploadedFile.key,
      mediaMimeType: mimeType || null,
      mediaSizeBytes: uploadedFile.size || null,
      mediaFileName: uploadedFile.originalname || null,
    });
    const row = await Message.findById(created.id);
    const [enriched] = await enrichMessages(row ? [row] : [created]);
    emitChatMessage(req, enriched, validation.receiverId);
    return res.status(201).json(enriched);
  } catch (error) {
    if (req.file?.key) {
      await deleteS3Object(req.file.key).catch(() => {});
    }
    console.error('[sendShipmentMediaMessage] Error:', error);
    return res.status(500).json({ message: 'خطأ في إرسال الوسائط' });
  }
};

const sendShipmentLocationMessage = async (req, res) => {
  try {
    const { shipmentId } = req.params;
    const { receiverId, latitude, longitude, label } = req.body;
    const lat = parseCoordinate(latitude);
    const lng = parseCoordinate(longitude);
    if (!shipmentId || lat == null || lng == null) {
      return res.status(400).json({ message: 'بيانات الموقع غير مكتملة' });
    }
    if (lat < -90 || lat > 90 || lng < -180 || lng > 180) {
      return res.status(400).json({ message: 'إحداثيات الموقع غير صحيحة' });
    }

    const validation = await validateShipmentChatSend({
      shipmentId,
      senderId: req.user?.id,
      receiverId,
    });
    if (validation.status) {
      return res.status(validation.status).json({ message: validation.message });
    }

    const locationLabel = label?.toString().trim() || 'موقع';
    const created = await Message.create({
      shipmentId: Number(validation.shipment.id),
      senderId: Number(req.user.id),
      receiverId: Number(validation.receiverId),
      messageType: 'location',
      message: locationLabel,
      locationLat: lat,
      locationLng: lng,
      locationLabel,
    });
    const row = await Message.findById(created.id);
    const [enriched] = await enrichMessages(row ? [row] : [created]);
    emitChatMessage(req, enriched, validation.receiverId);
    return res.status(201).json(enriched);
  } catch (error) {
    console.error('[sendShipmentLocationMessage] Error:', error);
    return res.status(500).json({ message: 'خطأ في إرسال الموقع' });
  }
};

const listMyConversations = async (req, res) => {
  try {
    const userId = req.user?.id;
    if (!userId) {
      return res.status(401).json({ message: 'غير مصرح' });
    }
    const rows = await enrichConversationImages(await Message.listConversationSummariesForUser(userId));
    return res.json(rows);
  } catch (error) {
    console.error('[listMyConversations] Error:', error);
    return res.status(500).json({ message: 'خطأ في جلب المحادثات' });
  }
};

const markShipmentMessagesDelivered = async (req, res) => {
  try {
    const { shipmentId } = req.params;
    const shipment = await Shipment.findById(shipmentId);
    if (!shipment) {
      return res.status(404).json({ message: 'الشحنة غير موجودة' });
    }
    if (!hasShipmentChatAccess(shipment, req.user?.id)) {
      return res.status(403).json({ message: 'غير مصرح لك بهذه المحادثة' });
    }

    const updates = await Message.markDelivered({
      shipmentId: Number(shipmentId),
      receiverId: Number(req.user.id),
      messageIds: parseMessageIds(req.body?.messageIds),
    });
    emitReceiptUpdates(req, updates);
    return res.json({ updated: updates.length, messages: updates });
  } catch (error) {
    console.error('[markShipmentMessagesDelivered] Error:', error);
    return res.status(500).json({ message: 'خطأ في تحديث حالة التسليم' });
  }
};

const markShipmentMessagesRead = async (req, res) => {
  try {
    const { shipmentId } = req.params;
    const shipment = await Shipment.findById(shipmentId);
    if (!shipment) {
      return res.status(404).json({ message: 'الشحنة غير موجودة' });
    }
    if (!hasShipmentChatAccess(shipment, req.user?.id)) {
      return res.status(403).json({ message: 'غير مصرح لك بهذه المحادثة' });
    }

    const updates = await Message.markRead({
      shipmentId: Number(shipmentId),
      receiverId: Number(req.user.id),
      messageIds: parseMessageIds(req.body?.messageIds),
    });
    emitReceiptUpdates(req, updates);
    return res.json({ updated: updates.length, messages: updates });
  } catch (error) {
    console.error('[markShipmentMessagesRead] Error:', error);
    return res.status(500).json({ message: 'خطأ في تحديث حالة القراءة' });
  }
};

module.exports = {
  getShipmentChat,
  sendShipmentMessage,
  sendShipmentMediaMessage,
  sendShipmentLocationMessage,
  listMyConversations,
  markShipmentMessagesDelivered,
  markShipmentMessagesRead,
  hasShipmentChatAccess,
  allowedChatStatuses,
  validateShipmentChatSend,
};
