const pool = require('../config/db');

const Truck = {
  create: async ({ user_id, plate_number, isthimara_no, truck_type, capacity_kg, manufacturing_year, insurance_expiry_date, is_active = false }) => {
    const [result] = await pool.execute(
      'INSERT INTO trucks (user_id, plate_number, isthimara_no, truck_type, capacity_kg, manufacturing_year, insurance_expiry_date, verification_status, is_active) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [user_id, plate_number, isthimara_no, truck_type, capacity_kg, manufacturing_year, insurance_expiry_date, 'pending', is_active ? 1 : 0]
    );
    return {
      id: result.insertId,
      user_id: user_id,
      plate_number: plate_number,
      isthimara_no: isthimara_no,
      truck_type: truck_type,
      capacity_kg: capacity_kg,
      manufacturing_year: manufacturing_year,
      insurance_expiry_date: insurance_expiry_date,
      is_active: !!is_active,
      verification_status: 'pending',
    };
  },

  listByDriverId: async (user_id) => {
    const [rows] = await pool.execute('SELECT * FROM trucks WHERE user_id = ? ORDER BY is_active DESC, created_at DESC', [user_id]);
    return rows;
  },

  findById: async (id) => {
    const [rows] = await pool.execute('SELECT * FROM trucks WHERE id = ?', [id]);
    return rows[0];
  },

  countByDriverId: async (user_id) => {
    const [rows] = await pool.execute('SELECT COUNT(*) AS cnt FROM trucks WHERE user_id = ?', [user_id]);
    return Number(rows[0]?.cnt ?? 0);
  },

  findByPlateNumber: async (plate_number) => {
    const [rows] = await pool.execute('SELECT * FROM trucks WHERE plate_number = ? LIMIT 1', [plate_number]);
    return rows[0];
  },

  update: async (id, { plate_number, isthimara_no, truck_type, capacity_kg, manufacturing_year, insurance_expiry_date, is_active }) => {
    const [result] = await pool.execute(
      'UPDATE trucks SET plate_number = ?, isthimara_no = ?, truck_type = ?, capacity_kg = ?, manufacturing_year = ?, insurance_expiry_date = ?, is_active = ? WHERE id = ?',
      [plate_number, isthimara_no, truck_type, capacity_kg, manufacturing_year, insurance_expiry_date, is_active ? 1 : 0, id]
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
