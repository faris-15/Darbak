const pool = require('../config/db');

const User = {
  create: async ({ name, email, phone, password, role, companyName }) => {
    const [result] = await pool.execute(
      'INSERT INTO users (name, email, phone, password, role, company_name) VALUES (?, ?, ?, ?, ?, ?)',
      [name, email, phone, password, role, companyName || null]
    );
    return { id: result.insertId, name, email, phone, role, companyName };
  },

  findByEmail: async (email) => {
    const [rows] = await pool.execute('SELECT * FROM users WHERE email = ?', [email]);
    return rows[0];
  },

  findById: async (id) => {
    const [rows] = await pool.execute('SELECT * FROM users WHERE id = ?', [id]);
    return rows[0];
  },
};

module.exports = User;
