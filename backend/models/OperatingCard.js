const pool = require('../config/db');

class OperatingCard {
  static async create({ driver_id, file_url, file_key, file_type, expiry_date }) {
    const [result] = await pool.execute(
      `INSERT INTO driver_operating_cards
      (driver_id, file_url, file_key, file_type, expiry_date, verification_status)
      VALUES (?, ?, ?, ?, ?, 'pending')`,
      [driver_id, file_url, file_key, file_type, expiry_date]
    );
    return result.insertId;
  }

  static async findByDriverId(driverId) {
    const [rows] = await pool.execute(
      'SELECT * FROM driver_operating_cards WHERE driver_id = ? ORDER BY created_at DESC LIMIT 1',
      [driverId]
    );
    return rows[0];
  }

  static async update(id, { file_url, file_key, file_type, expiry_date }) {
    const [result] = await pool.execute(
      `UPDATE driver_operating_cards
       SET file_url = ?, file_key = ?, file_type = ?, expiry_date = ?, verification_status = 'pending', updated_at = CURRENT_TIMESTAMP
       WHERE id = ?`,
      [file_url, file_key, file_type, expiry_date, id]
    );
    return result.affectedRows > 0;
  }

  static async delete(id) {
    const [result] = await pool.execute('DELETE FROM driver_operating_cards WHERE id = ?', [id]);
    return result.affectedRows > 0;
  }

  static async updateStatus(id, { status, rejection_reason = null }) {
    const [result] = await pool.execute(
      `UPDATE driver_operating_cards
       SET verification_status = ?, rejection_reason = ?, verified_at = ?
       WHERE id = ?`,
      [status, rejection_reason, status === 'verified' ? new Date() : null, id]
    );
    return result.affectedRows > 0;
  }
}

module.exports = OperatingCard;
