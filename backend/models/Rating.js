const pool = require('../config/db');

let ratingColumnsCache = null;

const getRatingColumns = async () => {
  if (ratingColumnsCache) return ratingColumnsCache;

  const [columns] = await pool.execute('SHOW COLUMNS FROM ratings');
  const names = new Set(columns.map((column) => column.Field));

  // Some environments were migrated with ratee_id/rating_stars/comments while
  // newer dumps use rated_id/stars/comment. Resolve once so both API flows work.
  const schema = {
    ratedColumn: names.has('rated_id') ? 'rated_id' : 'ratee_id',
    starsColumn: names.has('stars') ? 'stars' : 'rating_stars',
    commentColumn: names.has('comment') ? 'comment' : 'comments',
    hasRaterRole: names.has('rater_role'),
    hasCreatedAt: names.has('created_at'),
  };

  if (!names.has(schema.ratedColumn) || !names.has(schema.starsColumn)) {
    throw new Error('Ratings table is missing rated user or stars columns');
  }

  ratingColumnsCache = schema;
  return schema;
};

const canonicalSelect = (schema) => `
  id,
  shipment_id,
  rater_id,
  ${schema.ratedColumn} AS rated_id,
  ${schema.starsColumn} AS stars,
  ${schema.commentColumn} AS comment
  ${schema.hasRaterRole ? ', rater_role' : ''}
  ${schema.hasCreatedAt ? ', created_at' : ''}
`;

const Rating = {
  getColumnMap: getRatingColumns,

  create: async ({ shipment_id, rater_id, rated_id, stars, comment, rater_role }) => {
    const schema = await getRatingColumns();
    const columns = ['shipment_id', 'rater_id', schema.ratedColumn, schema.starsColumn, schema.commentColumn];
    const values = [shipment_id, rater_id, rated_id, stars, comment || null];

    // Older installs require rater_role; current schema does not. Keep the API stable either way.
    if (schema.hasRaterRole) {
      columns.push('rater_role');
      values.push(rater_role);
    }

    const placeholders = columns.map(() => '?').join(', ');
    const [result] = await pool.execute(
      `INSERT INTO ratings (${columns.join(', ')}) VALUES (${placeholders})`,
      values
    );
    return {
      id: result.insertId,
      shipment_id,
      rater_id,
      rated_id,
      stars,
      comment: comment || null,
      ...(schema.hasRaterRole ? { rater_role } : {}),
    };
  },

  findByShipmentAndRater: async (shipment_id, rater_id) => {
    const schema = await getRatingColumns();
    const [rows] = await pool.execute(
      `SELECT ${canonicalSelect(schema)}
       FROM ratings
       WHERE shipment_id = ? AND rater_id = ?
       LIMIT 1`,
      [shipment_id, rater_id]
    );
    return rows[0];
  },

  findById: async (id) => {
    const schema = await getRatingColumns();
    const [rows] = await pool.execute(
      `SELECT ${canonicalSelect(schema)}
       FROM ratings
       WHERE id = ?
       LIMIT 1`,
      [id]
    );
    return rows[0];
  },

  findByUserId: async (userId) => {
    const schema = await getRatingColumns();
    const [rows] = await pool.execute(
      `SELECT ${canonicalSelect(schema)}
       FROM ratings
       WHERE ${schema.ratedColumn} = ?
         AND ${schema.starsColumn} BETWEEN 1 AND 5
       ORDER BY ${schema.hasCreatedAt ? 'created_at DESC' : 'id DESC'}`,
      [userId]
    );
    return rows;
  },

  getAverageRating: async (userId) => {
    const schema = await getRatingColumns();
    const [rows] = await pool.execute(
      `SELECT
        COALESCE(AVG(CASE WHEN ${schema.starsColumn} BETWEEN 1 AND 5 THEN ${schema.starsColumn} END), 0) AS average_rating,
        COUNT(CASE WHEN ${schema.starsColumn} BETWEEN 1 AND 5 THEN 1 END) AS total_ratings
      FROM ratings
      WHERE ${schema.ratedColumn} = ?`,
      [userId]
    );
    const averageRating = Number(rows[0]?.average_rating ?? 0);
    const totalRatings = Number(rows[0]?.total_ratings ?? 0);

    return {
      average_rating: Number.isFinite(averageRating) ? averageRating : 0,
      total_ratings: Number.isFinite(totalRatings) ? totalRatings : 0,
    };
  },

  update: async (id, { stars, comment }) => {
    const schema = await getRatingColumns();
    const [result] = await pool.execute(
      `UPDATE ratings SET ${schema.starsColumn} = ?, ${schema.commentColumn} = ? WHERE id = ?`,
      [stars, comment || null, id]
    );
    return result.affectedRows > 0;
  },

  delete: async (id) => {
    const [result] = await pool.execute('DELETE FROM ratings WHERE id = ?', [id]);
    return result.affectedRows > 0;
  },
};

module.exports = Rating;
