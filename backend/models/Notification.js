const pool = require('../config/db');

const Notification = {
  create: async ({ user_id, title, message, is_read = 0 }) => {
    const [result] = await pool.execute(
      'INSERT INTO notifications (user_id, title, message, is_read) VALUES (?, ?, ?, ?)',
      [user_id, title, message, is_read]
    );
    return {
      id: result.insertId,
      user_id: user_id,
      title: title,
      message: message,
      is_read: is_read,
      created_at: new Date(),
    };
  },

  findByUserId: async (user_id, unreadOnly = false) => {
    let query = 'SELECT * FROM notifications WHERE user_id = ?';
    const params = [user_id];

    if (unreadOnly) {
      query += ' AND is_read = 0';
    }

    query += ' ORDER BY created_at DESC LIMIT 50';

    const [rows] = await pool.execute(query, params);
    return rows;
  },

  findById: async (id) => {
    const [rows] = await pool.execute('SELECT * FROM notifications WHERE id = ?', [id]);
    return rows[0];
  },

  markAsRead: async (id) => {
    const [result] = await pool.execute('UPDATE notifications SET is_read = 1 WHERE id = ?', [id]);
    return result.affectedRows > 0;
  },

  markAllAsRead: async (user_id) => {
    const [result] = await pool.execute('UPDATE notifications SET is_read = 1 WHERE user_id = ? AND is_read = 0', [user_id]);
    return result.affectedRows > 0;
  },

  delete: async (id) => {
    const [result] = await pool.execute('DELETE FROM notifications WHERE id = ?', [id]);
    return result.affectedRows > 0;
  },

  deleteOldNotifications: async (daysOld = 30) => {
    const [result] = await pool.execute(
      'DELETE FROM notifications WHERE created_at < DATE_SUB(NOW(), INTERVAL ? DAY)',
      [daysOld]
    );
    return result.affectedRows;
  },

  getUnreadCount: async (user_id) => {
    const [rows] = await pool.execute('SELECT COUNT(*) as unread_count FROM notifications WHERE user_id = ? AND is_read = 0', [user_id]);
    return rows[0]?.unread_count || 0;
  },
};

module.exports = Notification;
