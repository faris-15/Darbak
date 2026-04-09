const pool = require('../config/db');

const Rating = {
  create: async ({ shipment_id, rater_id, rated_id, stars, comment }) => {
    const [result] = await pool.execute(
      'INSERT INTO ratings (shipment_id, rater_id, rated_id, stars, comment) VALUES (?, ?, ?, ?, ?)',
      [shipment_id, rater_id, rated_id, stars, comment]
    );
    return {
      id: result.insertId,
      shipment_id: shipment_id,
      rater_id: rater_id,
      rated_id: rated_id,
      stars: stars,
      comment: comment,
    };
  },

  findByShipmentAndRater: async (shipment_id, rater_id) => {
    const [rows] = await pool.execute(
      'SELECT * FROM ratings WHERE shipment_id = ? AND rater_id = ?',
      [shipment_id, rater_id]
    );
    return rows[0];
  },

  findByUserId: async (userId) => {
    const [rows] = await pool.execute(
      'SELECT * FROM ratings WHERE rated_id = ? ORDER BY created_at DESC',
      [userId]
    );
    return rows;
  },

  getAverageRating: async (userId) => {
    const [rows] = await pool.execute(
      'SELECT AVG(stars) as avg_rating, COUNT(*) as total_ratings FROM ratings WHERE rated_id = ?',
      [userId]
    );
    return {
      average_rating: rows[0]?.avg_rating || 0,
      total_ratings: rows[0]?.total_ratings || 0,
    };
  },

  update: async (id, { stars, comment }) => {
    const [result] = await pool.execute(
      'UPDATE ratings SET stars = ?, comment = ? WHERE id = ?',
      [stars, comment, id]
    );
    return result.affectedRows > 0;
  },

  delete: async (id) => {
    const [result] = await pool.execute('DELETE FROM ratings WHERE id = ?', [id]);
    return result.affectedRows > 0;
  },
};

module.exports = Rating;
