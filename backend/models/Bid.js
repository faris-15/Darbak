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
};

module.exports = Bid;