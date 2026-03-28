const pool = require('../config/db');

const Bid = {
  create: async ({ shipmentId, driverId, amount, etaDays }) => {
    const [result] = await pool.execute(
      'INSERT INTO bids (shipment_id, driver_id, amount, eta_days) VALUES (?, ?, ?, ?)',
      [shipmentId, driverId, amount, etaDays]
    );
    return { id: result.insertId, shipmentId, driverId, amount, etaDays };
  },

  findByShipment: async (shipmentId) => {
    const [rows] = await pool.execute('SELECT * FROM bids WHERE shipment_id = ?', [shipmentId]);
    return rows;
  },
};

module.exports = Bid;