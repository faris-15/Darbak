const Message = require('../models/Message');
const Shipment = require('../models/Shipment');

const allowedChatStatuses = new Set(['assigned', 'at_pickup', 'en_route', 'at_dropoff']);

const hasShipmentChatAccess = (shipment, userId) =>
  Number(shipment.shipper_id) === Number(userId) || Number(shipment.driver_id) === Number(userId);

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
    const messages = await Message.listByShipment(shipmentId);
    return res.json(messages);
  } catch (error) {
    console.error('[getShipmentChat] Error:', error);
    return res.status(500).json({ message: 'خطأ في جلب المحادثة' });
  }
};

const sendShipmentMessage = async (req, res) => {
  try {
    const { shipmentId, receiverId, message } = req.body;
    if (!shipmentId || !receiverId || !message?.toString().trim()) {
      return res.status(400).json({ message: 'بيانات الرسالة غير مكتملة' });
    }
    const shipment = await Shipment.findById(shipmentId);
    if (!shipment) {
      return res.status(404).json({ message: 'الشحنة غير موجودة' });
    }
    if (!allowedChatStatuses.has(shipment.status)) {
      return res.status(400).json({ message: 'المحادثة متاحة فقط بعد قبول العرض' });
    }
    if (!hasShipmentChatAccess(shipment, req.user?.id)) {
      return res.status(403).json({ message: 'غير مصرح لك بإرسال رسائل لهذه الشحنة' });
    }
    if (!hasShipmentChatAccess(shipment, receiverId)) {
      return res.status(400).json({ message: 'المستقبل غير مرتبط بهذه الشحنة' });
    }

    const created = await Message.create({
      shipmentId: Number(shipmentId),
      senderId: Number(req.user.id),
      receiverId: Number(receiverId),
      message: message.toString().trim(),
    });
    return res.status(201).json(created);
  } catch (error) {
    console.error('[sendShipmentMessage] Error:', error);
    return res.status(500).json({ message: 'خطأ في إرسال الرسالة' });
  }
};

const listMyConversations = async (req, res) => {
  try {
    const userId = req.user?.id;
    if (!userId) {
      return res.status(401).json({ message: 'غير مصرح' });
    }
    const rows = await Message.listConversationSummariesForUser(userId);
    return res.json(rows);
  } catch (error) {
    console.error('[listMyConversations] Error:', error);
    return res.status(500).json({ message: 'خطأ في جلب المحادثات' });
  }
};

module.exports = {
  getShipmentChat,
  sendShipmentMessage,
  listMyConversations,
};
