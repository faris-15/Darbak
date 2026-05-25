const Conversation = require('../models/Conversation');

const postMessage = async (req, res) => {
  try {
    const { shipmentId, senderId, receiverId, message } = req.body;
    const convo = await Conversation.create({ shipmentId, senderId, receiverId, message });
    res.status(201).json(convo);
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'خطأ في إرسال الرسالة' });
  }
};

const getConversation = async (req, res) => {
  try {
    const { shipmentId } = req.params;
    const messages = await Conversation.findByShipment(shipmentId);
    res.json(messages);
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'خطأ في جلب المحادثة' });
  }
};

const getOrCreateConversation = async (req, res) => {
  try {
    const senderId = Number(req.body.sender_id);
    const receiverId = Number(req.body.receiver_id);

    if (!Number.isInteger(senderId) || !Number.isInteger(receiverId) || senderId <= 0 || receiverId <= 0) {
      return res.status(400).json({ message: 'بيانات المستخدمين غير صحيحة' });
    }
    if (senderId === receiverId) {
      return res.status(400).json({ message: 'لا يمكن إنشاء محادثة مع نفس المستخدم' });
    }

    const result = await Conversation.getOrCreateDirect({
      senderId,
      receiverId,
    });

    return res.status(result.created ? 201 : 200).json(result);
  } catch (error) {
    console.error('[getOrCreateConversation] Error:', error);
    return res.status(500).json({ message: 'خطأ في إنشاء أو جلب المحادثة' });
  }
};

module.exports = { postMessage, getConversation, getOrCreateConversation };