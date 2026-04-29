const pool = require('../config/db');

const Message = {
  create: async ({ shipmentId, senderId, receiverId, message }) => {
    const [result] = await pool.execute(
      'INSERT INTO messages (shipment_id, sender_id, receiver_id, message) VALUES (?, ?, ?, ?)',
      [shipmentId, senderId, receiverId, message]
    );
    return {
      id: result.insertId,
      shipment_id: shipmentId,
      sender_id: senderId,
      receiver_id: receiverId,
      message,
      created_at: new Date(),
    };
  },

  listByShipment: async (shipmentId) => {
    const [rows] = await pool.execute(
      `SELECT m.*, u.full_name AS sender_name
       FROM messages m
       LEFT JOIN users u ON u.id = m.sender_id
       WHERE m.shipment_id = ?
       ORDER BY m.created_at ASC`,
      [shipmentId]
    );
    return rows;
  },
};

module.exports = Message;
