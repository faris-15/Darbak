const pool = require('../config/db');

const Conversation = {
  create: async ({ shipmentId, senderId, receiverId, message }) => {
    const [result] = await pool.execute(
      'INSERT INTO conversations (shipment_id, sender_id, receiver_id, message) VALUES (?, ?, ?, ?)',
      [shipmentId, senderId, receiverId, message]
    );
    return { id: result.insertId, shipmentId, senderId, receiverId, message };
  },

  findByShipment: async (shipmentId) => {
    const [rows] = await pool.execute('SELECT * FROM conversations WHERE shipment_id = ? ORDER BY created_at ASC', [shipmentId]);
    return rows;
  },
};

module.exports = Conversation;