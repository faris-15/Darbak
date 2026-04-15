const pool = require('../config/db');

const Bid = {
  create: async ({ shipmentId, driverId, bidAmount, estimatedDays }) => {
    const [result] = await pool.execute(
      'INSERT INTO bids (shipment_id, driver_id, bid_amount, estimated_days) VALUES (?, ?, ?, ?)',
      [shipmentId, driverId, bidAmount, estimatedDays]
    );
    return { id: result.insertId, shipmentId, driverId, bid_amount: bidAmount, estimated_days: estimatedDays };
  },

  findByShipment: async (shipmentId) => {
    const [rows] = await pool.execute('SELECT * FROM bids WHERE shipment_id = ? ORDER BY bid_amount ASC', [shipmentId]);
    return rows;
  },

  findById: async (id) => {
    const [rows] = await pool.execute('SELECT * FROM bids WHERE id = ?', [id]);
    return rows[0];
  },

  setStatus: async (id, status) => {
    const [result] = await pool.execute('UPDATE bids SET bid_status = ? WHERE id = ?', [status, id]);
    return result.affectedRows > 0;
  },

  rejectOtherBidsForShipment: async (shipmentId, acceptedBidId) => {
    const [result] = await pool.execute('UPDATE bids SET bid_status = ? WHERE shipment_id = ? AND id != ?', ['rejected', shipmentId, acceptedBidId]);
    return result.affectedRows;
  },

  findByShipmentWithDriver: async (shipmentId) => {
    const [rows] = await pool.execute(
      `SELECT 
        b.id, 
        b.shipment_id, 
        b.driver_id, 
        b.bid_amount, 
        b.estimated_days, 
        b.bid_status,
        u.id as user_id,
        u.full_name as driver_name,
        u.license_no,
        u.phone,
        (SELECT COALESCE(AVG(stars), 0) FROM ratings WHERE rated_id = b.driver_id) as driver_rating,
        (SELECT COUNT(*) FROM ratings WHERE rated_id = b.driver_id) as rating_count
      FROM bids b
      LEFT JOIN users u ON b.driver_id = u.id
      WHERE b.shipment_id = ?
      ORDER BY b.bid_amount ASC`,
      [shipmentId]
    );
    return rows;
  },

  acceptBid: async (bidId, shipmentId) => {
    const [result] = await pool.execute(
      'UPDATE bids SET bid_status = ? WHERE id = ?',
      ['accepted', bidId]
    );
    return result.affectedRows > 0;
  },
};

module.exports = Bid;