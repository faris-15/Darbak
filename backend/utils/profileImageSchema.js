const pool = require('../config/db');

let ensurePromise = null;

async function profileImageColumnExists() {
  const [rows] = await pool.execute(
    `SELECT COUNT(*) AS count
     FROM INFORMATION_SCHEMA.COLUMNS
     WHERE TABLE_SCHEMA = DATABASE()
       AND TABLE_NAME = 'users'
       AND COLUMN_NAME = 'profile_image_url'`
  );
  return Number(rows[0]?.count || 0) > 0;
}

async function ensureProfileImageSchema() {
  if (ensurePromise) return ensurePromise;

  ensurePromise = (async () => {
    if (!(await profileImageColumnExists())) {
      await pool.execute(
        'ALTER TABLE users ADD COLUMN profile_image_url VARCHAR(1000) NULL AFTER document_path'
      );
    }
  })().catch((error) => {
    ensurePromise = null;
    throw error;
  });

  return ensurePromise;
}

module.exports = { ensureProfileImageSchema };
