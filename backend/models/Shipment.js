const pool = require('../config/db');

const Shipment = {
  create: async ({ shipperId, origin, destination, freightType, weight, value, edt }) => {
    const [result] = await pool.execute(
      'INSERT INTO shipments (shipper_id, origin, destination, freight_type, weight, value, edt) VALUES (?, ?, ?, ?, ?, ?, ?)',
      [shipperId, origin, destination, freightType, weight, value, edt]
    );
    return { id: result.insertId, shipperId, origin, destination, freightType, weight, value, edt };
  },

  findById: async (id) => {
    const [rows] = await pool.execute('SELECT * FROM shipments WHERE id = ?', [id]);
    return rows[0];
  },

  list: async () => {
    const [rows] = await pool.execute('SELECT * FROM shipments ORDER BY created_at DESC');
    return rows;
  },
};

module.exports = Shipment;
