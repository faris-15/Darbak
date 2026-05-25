const pool = require('../config/db');

let ensurePromise = null;

async function columnExists(columnName) {
  const [rows] = await pool.execute(
    `SELECT COUNT(*) AS count
     FROM INFORMATION_SCHEMA.COLUMNS
     WHERE TABLE_SCHEMA = DATABASE()
       AND TABLE_NAME = 'compliance_documents'
       AND COLUMN_NAME = ?`,
    [columnName]
  );
  return Number(rows[0]?.count || 0) > 0;
}

async function indexExists(indexName) {
  const [rows] = await pool.execute(
    `SELECT COUNT(*) AS count
     FROM INFORMATION_SCHEMA.STATISTICS
     WHERE TABLE_SCHEMA = DATABASE()
       AND TABLE_NAME = 'compliance_documents'
       AND INDEX_NAME = ?`,
    [indexName]
  );
  return Number(rows[0]?.count || 0) > 0;
}

async function constraintExists(constraintName) {
  const [rows] = await pool.execute(
    `SELECT COUNT(*) AS count
     FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS
     WHERE TABLE_SCHEMA = DATABASE()
       AND TABLE_NAME = 'compliance_documents'
       AND CONSTRAINT_NAME = ?`,
    [constraintName]
  );
  return Number(rows[0]?.count || 0) > 0;
}

async function safeAlter(sql, label, { required = true } = {}) {
  try {
    await pool.execute(sql);
    return true;
  } catch (error) {
    // Another concurrent request may have applied the same ALTER first.
    if (error && ['ER_DUP_FIELDNAME', 'ER_DUP_KEYNAME', 'ER_FK_DUP_NAME'].includes(error.code)) {
      return true;
    }
    console.error(`[Schema] Failed to apply ${label}:`, error.message);
    if (!required) {
      return false;
    }
    throw error;
  }
}

async function ensureTruckInsuranceSchema() {
  if (ensurePromise) return ensurePromise;

  ensurePromise = (async () => {
    if (!(await columnExists('truck_id'))) {
      await safeAlter(
        'ALTER TABLE compliance_documents ADD COLUMN truck_id INT(11) NULL AFTER user_id',
        'compliance_documents.truck_id'
      );
    }

    if (!(await indexExists('idx_truck_id'))) {
      await safeAlter(
        'ALTER TABLE compliance_documents ADD KEY idx_truck_id (truck_id)',
        'idx_truck_id'
      );
    }

    if (!(await indexExists('idx_truck_document_type'))) {
      await safeAlter(
        'ALTER TABLE compliance_documents ADD KEY idx_truck_document_type (truck_id, document_type)',
        'idx_truck_document_type'
      );
    }

    if (!(await constraintExists('compliance_documents_truck_fk'))) {
      await safeAlter(
        `ALTER TABLE compliance_documents
         ADD CONSTRAINT compliance_documents_truck_fk
         FOREIGN KEY (truck_id) REFERENCES trucks (id) ON DELETE CASCADE`,
        'compliance_documents_truck_fk',
        { required: false }
      );
    }
  })().catch((error) => {
    ensurePromise = null;
    throw error;
  });

  return ensurePromise;
}

module.exports = { ensureTruckInsuranceSchema };
