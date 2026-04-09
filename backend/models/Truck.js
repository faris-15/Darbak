const pool = require('../config/db');

const Truck = {
  create: async ({ user_id, plate_number, truck_type, capacity_kg, manufacturing_year, insurance_expiry_date }) => {
    const [result] = await pool.execute(
      'INSERT INTO trucks (user_id, plate_number, truck_type, capacity_kg, manufacturing_year, insurance_expiry_date, verification_status) VALUES (?, ?, ?, ?, ?, ?, ?)',
      [user_id, plate_number, truck_type, capacity_kg, manufacturing_year, insurance_expiry_date, 'pending']
    );
    return {
      id: result.insertId,
      user_id: user_id,
      plate_number: plate_number,
      truck_type: truck_type,
      capacity_kg: capacity_kg,
      manufacturing_year: manufacturing_year,
      insurance_expiry_date: insurance_expiry_date,
      verification_status: 'pending',
    };
  },

  findByDriverId: async (user_id) => {
    const [rows] = await pool.execute('SELECT * FROM trucks WHERE user_id = ?', [user_id]);
    return rows[0];
  },

  findById: async (id) => {
    const [rows] = await pool.execute('SELECT * FROM trucks WHERE id = ?', [id]);
    return rows[0];
  },

  update: async (id, { plate_number, truck_type, capacity_kg, manufacturing_year, insurance_expiry_date }) => {
    const [result] = await pool.execute(
      'UPDATE trucks SET plate_number = ?, truck_type = ?, capacity_kg = ?, manufacturing_year = ?, insurance_expiry_date = ? WHERE id = ?',
      [plate_number, truck_type, capacity_kg, manufacturing_year, insurance_expiry_date, id]
    );
    return result.affectedRows > 0;
  },

  verifyTruck: async (id, status) => {
    const [result] = await pool.execute('UPDATE trucks SET verification_status = ? WHERE id = ?', [status, id]);
    return result.affectedRows > 0;
  },

  list: async () => {
    const [rows] = await pool.execute('SELECT * FROM trucks ORDER BY created_at DESC');
    return rows;
  },

  listPending: async () => {
    const [rows] = await pool.execute('SELECT * FROM trucks WHERE verification_status = "pending" ORDER BY created_at ASC');
    return rows;
  },
};

module.exports = Truck;
