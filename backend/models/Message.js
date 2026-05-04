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

  /**
   * One row per shipment the user participates in, with last message metadata.
   */
  listConversationSummariesForUser: async (userId) => {
    const [rows] = await pool.execute(
      `SELECT
         sub.shipment_id,
         sub.last_message,
         sub.last_message_at,
         sub.last_sender_id,
         s.pickup_address,
         s.dropoff_address,
         s.status,
         s.shipper_id,
         s.driver_id,
         CASE WHEN s.shipper_id = ? THEN u_driver.full_name ELSE u_shipper.full_name END AS other_party_name
       FROM (
         SELECT m.shipment_id, m.message AS last_message, m.created_at AS last_message_at, m.sender_id AS last_sender_id
         FROM messages m
         INNER JOIN (
           SELECT shipment_id, MAX(id) AS mid
           FROM messages
           WHERE sender_id = ? OR receiver_id = ?
           GROUP BY shipment_id
         ) x ON m.id = x.mid
       ) sub
       INNER JOIN shipments s ON s.id = sub.shipment_id
       LEFT JOIN users u_shipper ON u_shipper.id = s.shipper_id
       LEFT JOIN users u_driver ON u_driver.id = s.driver_id`,
      [userId, userId, userId]
    );
    return rows;
  },
};

module.exports = Message;
