const pool = require('../config/db');
const {
  LEGACY_TRUCK_TYPE_MAP,
  buildDisplayLabelAr,
} = require('../constants/truckClassification');

let ensurePromise = null;

async function columnExists(tableName, columnName) {
  const [rows] = await pool.execute(
    `SELECT COUNT(*) AS count
     FROM INFORMATION_SCHEMA.COLUMNS
     WHERE TABLE_SCHEMA = DATABASE()
       AND TABLE_NAME = ?
       AND COLUMN_NAME = ?`,
    [tableName, columnName]
  );
  return Number(rows[0]?.count || 0) > 0;
}

async function safeAlter(sql, label) {
  try {
    await pool.execute(sql);
    return true;
  } catch (error) {
    if (error && ['ER_DUP_FIELDNAME', 'ER_DUP_KEYNAME'].includes(error.code)) {
      return true;
    }
    console.error(`[TruckClassificationSchema] ${label}:`, error.message);
    throw error;
  }
}

async function migrateLegacyTruckTypes() {
  for (const [legacyType, mapped] of Object.entries(LEGACY_TRUCK_TYPE_MAP)) {
    const label = buildDisplayLabelAr(mapped);
    const capacityKg = Math.round((mapped.max_weight_tons || 0) * 1000);
    await pool.execute(
      `UPDATE trucks
       SET category = ?,
           axle_count = ?,
           body_type = ?,
           payload_capacity = ?,
           max_weight_tons = ?,
           capacity_kg = CASE WHEN capacity_kg IS NULL OR capacity_kg = 0 THEN ? ELSE capacity_kg END,
           truck_type = CASE WHEN truck_type IS NULL OR truck_type = '' THEN ? ELSE truck_type END
       WHERE truck_type = ?
         AND (category IS NULL OR category = '' OR category = 'legacy_unknown')`,
      [
        mapped.category,
        mapped.axle_count,
        mapped.body_type,
        mapped.payload_capacity,
        mapped.max_weight_tons,
        capacityKg,
        label,
        legacyType,
      ]
    );
  }

  await pool.execute(
    `UPDATE trucks
     SET category = 'medium_double_5_10',
         axle_count = COALESCE(axle_count, 2),
         body_type = COALESCE(body_type, 'box'),
         payload_capacity = COALESCE(payload_capacity, '5_10'),
         max_weight_tons = COALESCE(max_weight_tons, 7.5),
         capacity_kg = CASE WHEN capacity_kg IS NULL OR capacity_kg = 0 THEN 7500 ELSE capacity_kg END,
         truck_type = COALESCE(NULLIF(truck_type, ''), 'شاحنة — بيانات قديمة')
     WHERE category IS NULL OR category = ''`
  );
}

async function ensureTruckClassificationSchema() {
  if (ensurePromise) return ensurePromise;

  ensurePromise = (async () => {
    const hasCategory = await columnExists('trucks', 'category');
    if (!hasCategory) {
      await safeAlter(
        `ALTER TABLE trucks
           ADD COLUMN category VARCHAR(64) NULL AFTER truck_type,
           ADD COLUMN axle_count TINYINT UNSIGNED NULL AFTER category,
           ADD COLUMN body_type VARCHAR(64) NULL AFTER axle_count,
           ADD COLUMN payload_capacity VARCHAR(32) NULL AFTER body_type,
           ADD COLUMN max_weight_tons DECIMAL(10,2) NULL AFTER payload_capacity`,
        'add classification columns'
      );
    }

    // Relax legacy enum so migrated + new values persist safely.
    await safeAlter(
      `ALTER TABLE trucks MODIFY truck_type VARCHAR(255) NULL`,
      'widen truck_type column'
    );

    await migrateLegacyTruckTypes();

    await safeAlter(
      `ALTER TABLE trucks
         MODIFY category VARCHAR(64) NOT NULL DEFAULT 'legacy_unknown',
         MODIFY axle_count TINYINT UNSIGNED NOT NULL DEFAULT 2,
         MODIFY body_type VARCHAR(64) NOT NULL DEFAULT 'standard_cargo',
         MODIFY payload_capacity VARCHAR(32) NOT NULL DEFAULT '5_10',
         MODIFY max_weight_tons DECIMAL(10,2) NOT NULL DEFAULT 7.50`,
      'enforce classification not null defaults'
    );

    await safeAlter(
      'CREATE INDEX idx_trucks_category ON trucks (category)',
      'category index'
    ).catch(() => true);

    await safeAlter(
      'CREATE INDEX idx_trucks_max_weight ON trucks (max_weight_tons)',
      'max weight index'
    ).catch(() => true);

    console.log('[TruckClassificationSchema] Ready');
  })().catch((error) => {
    ensurePromise = null;
    throw error;
  });

  return ensurePromise;
}

module.exports = { ensureTruckClassificationSchema };
