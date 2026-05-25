const pool = require('../config/db');

let ensurePromise = null;

async function columnExists(columnName) {
  const [rows] = await pool.execute(
    `SELECT COUNT(*) AS count
     FROM INFORMATION_SCHEMA.COLUMNS
     WHERE TABLE_SCHEMA = DATABASE()
       AND TABLE_NAME = 'shipments'
       AND COLUMN_NAME = ?`,
    [columnName]
  );
  return Number(rows[0]?.count || 0) > 0;
}

async function ensureShipmentTruckSchema() {
  if (ensurePromise) return ensurePromise;

  ensurePromise = (async () => {
    const hasGroup = await columnExists('required_truck_group');
    if (!hasGroup) {
      await pool.execute(
        `ALTER TABLE shipments
           ADD COLUMN required_truck_group VARCHAR(32) NULL AFTER cargo_description,
           ADD COLUMN required_truck_category VARCHAR(64) NULL AFTER required_truck_group,
           ADD COLUMN required_axle_count TINYINT UNSIGNED NULL AFTER required_truck_category,
           ADD COLUMN required_body_type VARCHAR(64) NULL AFTER required_axle_count,
           ADD COLUMN required_min_capacity_tons DECIMAL(10,2) NULL AFTER required_body_type`
      );
    }
  })().catch((err) => {
    ensurePromise = null;
    throw err;
  });

  return ensurePromise;
}

module.exports = { ensureShipmentTruckSchema };
