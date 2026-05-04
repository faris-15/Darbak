const pool = require('../config/db');

const User = {
  create: async ({ fullName, email, phone, password, role = 'driver', licenseNo = null, commercialNo = null, documentPath = null, issueDate = null, expiryDate = null }) => {
    const [result] = await pool.execute(
      'INSERT INTO users (full_name, email, phone, password, role, license_no, commercial_no, document_path, issue_date, expiry_date) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [fullName, email, phone, password, role, licenseNo, commercialNo, documentPath, issueDate, expiryDate]
    );
    return {
      id: result.insertId,
      full_name: fullName,
      email,
      phone,
      role,
      verification_status: 'pending',
      license_no: licenseNo,
      commercial_no: commercialNo,
      document_path: documentPath,
      issue_date: issueDate,
      expiry_date: expiryDate,
    };
  },

  findByPhoneOrEmail: async (identifier) => {
    const [rows] = await pool.execute('SELECT * FROM users WHERE phone = ? OR email = ?', [identifier, identifier]);
    return rows[0];
  },

  existsByPhone: async (phone) => {
    const [rows] = await pool.execute(
      'SELECT id FROM users WHERE phone = ? LIMIT 1',
      [phone]
    );
    return rows.length > 0;
  },

  existsByEmail: async (email) => {
    const [rows] = await pool.execute(
      'SELECT id FROM users WHERE LOWER(email) = LOWER(?) LIMIT 1',
      [email]
    );
    return rows.length > 0;
  },

  findById: async (id) => {
    const [rows] = await pool.execute('SELECT * FROM users WHERE id = ?', [id]);
    return rows[0];
  },

  getPendingVerifications: async () => {
    const [rows] = await pool.execute('SELECT id, full_name, phone, role, license_no, commercial_no, document_path, verification_status, created_at FROM users WHERE verification_status = ?', ['pending']);
    return rows;
  },

  updateVerificationStatus: async (id, status) => {
    const [result] = await pool.execute('UPDATE users SET verification_status = ? WHERE id = ?', [status, id]);
    return result.affectedRows > 0;
  },

  /** يتطلب عمود `is_active` (انظر migrations_06_admin_dashboard.sql) */
  updateActiveFlag: async (id, active) => {
    const [result] = await pool.execute('UPDATE users SET is_active = ? WHERE id = ?', [
      active ? 1 : 0,
      id,
    ]);
    return result.affectedRows > 0;
  },
};

module.exports = User;
