const pool = require('../config/db');

const Contract = {
  findByShipmentId: async (shipmentId) => {
    const [rows] = await pool.execute(
      'SELECT * FROM contracts WHERE shipment_id = ? LIMIT 1',
      [shipmentId],
    );
    return rows[0] || null;
  },
};

module.exports = Contract;
