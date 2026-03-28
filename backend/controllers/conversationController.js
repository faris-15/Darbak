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

module.exports = { postMessage, getConversation };