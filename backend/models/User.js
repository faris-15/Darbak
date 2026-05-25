const pool = require('../config/db');
const { ensureProfileImageSchema } = require('../utils/profileImageSchema');

const User = {
  create: async ({ fullName, email, phone, password, role = 'driver', licenseNo = null, commercialNo = null, documentPath = null, issueDate = null, expiryDate = null }) => {
    const [result] = await pool.execute(
      'INSERT INTO users (full_name, email, phone, password, role, license_no, commercial_no, document_path, issue_date, expiry_date, is_active) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [fullName, email, phone, password, role, licenseNo, commercialNo, documentPath, issueDate, expiryDate, 1]
    );
    return {
      id: result.insertId,
      full_name: fullName,
      email,
      phone,
      role,
      is_active: 1,
      verification_status: 'pending',
      license_no: licenseNo,
      commercial_no: commercialNo,
      document_path: documentPath,
      issue_date: issueDate,
      expiry_date: expiryDate,
    };
  },

  findByPhoneOrEmail: async (identifier) => {
    await ensureProfileImageSchema();
    const [rows] = await pool.execute('SELECT * FROM users WHERE phone = ? OR email = ?', [identifier, identifier]);
    return rows[0];
  },

  findByEmail: async (email) => {
    await ensureProfileImageSchema();
    const [rows] = await pool.execute('SELECT * FROM users WHERE LOWER(email) = LOWER(?) LIMIT 1', [email]);
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
    await ensureProfileImageSchema();
    const [rows] = await pool.execute('SELECT * FROM users WHERE id = ?', [id]);
    return rows[0];
  },

  /** `{ [userId]: full_name }` for driver shipment cards (batch). */
  getFullNamesByIds: async (ids) => {
    const unique = [
      ...new Set(
        (ids || [])
          .map((x) => Number(x))
          .filter((n) => Number.isFinite(n) && n > 0),
      ),
    ];
    if (!unique.length) return {};
    const placeholders = unique.map(() => '?').join(',');
    const [rows] = await pool.execute(
      `SELECT id, full_name FROM users WHERE id IN (${placeholders})`,
      unique,
    );
    const out = {};
    for (const r of rows) {
      out[Number(r.id)] = r.full_name;
    }
    return out;
  },

  updateProfileFields: async (id, { fullName, email, phone, licenseNo, commercialNo }) => {
    await ensureProfileImageSchema();
    const [result] = await pool.execute(
      'UPDATE users SET full_name = ?, email = ?, phone = ?, license_no = ?, commercial_no = ? WHERE id = ?',
      [fullName, email, phone, licenseNo, commercialNo, id]
    );
    return result.affectedRows > 0;
  },

  updateProfileImage: async (id, profileImageUrl) => {
    await ensureProfileImageSchema();
    const [result] = await pool.execute(
      'UPDATE users SET profile_image_url = ? WHERE id = ?',
      [profileImageUrl, id]
    );
    return result.affectedRows > 0;
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
