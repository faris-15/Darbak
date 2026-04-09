const pool = require('../config/db');

const Wallet = {
  createForUser: async (userId) => {
    const [result] = await pool.execute(
      'INSERT INTO wallets (user_id, current_balance) VALUES (?, ?)',
      [userId, 0.00]
    );
    return { id: result.insertId, user_id: userId, current_balance: 0.00 };
  },

  getByUserId: async (userId) => {
    const [rows] = await pool.execute('SELECT * FROM wallets WHERE user_id = ?', [userId]);
    return rows[0];
  },

  adjustBalance: async (userId, amount) => {
    const [result] = await pool.execute(
      'UPDATE wallets SET current_balance = current_balance + ? WHERE user_id = ?',
      [amount, userId]
    );
    return result.affectedRows > 0;
  },
};

module.exports = Wallet;
