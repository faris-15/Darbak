const pool = require('../config/db');

let ensurePromise = null;

async function columnExists(columnName) {
  const [rows] = await pool.execute(
    `SELECT COUNT(*) AS count
     FROM INFORMATION_SCHEMA.COLUMNS
     WHERE TABLE_SCHEMA = DATABASE()
       AND TABLE_NAME = 'messages'
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
       AND TABLE_NAME = 'messages'
       AND INDEX_NAME = ?`,
    [indexName]
  );
  return Number(rows[0]?.count || 0) > 0;
}

async function safeAlter(sql, label) {
  try {
    await pool.execute(sql);
  } catch (error) {
    // Another request or a manual migration may have applied the same ALTER first.
    if (error && ['ER_DUP_FIELDNAME', 'ER_DUP_KEYNAME'].includes(error.code)) {
      return;
    }
    console.error(`[Schema] Failed to apply ${label}:`, error.message);
    throw error;
  }
}

async function ensureMessageStatusSchema() {
  if (ensurePromise) return ensurePromise;

  ensurePromise = (async () => {
    if (!(await columnExists('message_type'))) {
      await safeAlter(
        "ALTER TABLE messages ADD COLUMN message_type ENUM('text', 'image', 'video', 'location') NOT NULL DEFAULT 'text' AFTER receiver_id",
        'messages.message_type'
      );
    }

    if (!(await columnExists('media_key'))) {
      await safeAlter(
        'ALTER TABLE messages ADD COLUMN media_key VARCHAR(1000) NULL AFTER message',
        'messages.media_key'
      );
    }

    if (!(await columnExists('media_mime_type'))) {
      await safeAlter(
        'ALTER TABLE messages ADD COLUMN media_mime_type VARCHAR(120) NULL AFTER media_key',
        'messages.media_mime_type'
      );
    }

    if (!(await columnExists('media_size_bytes'))) {
      await safeAlter(
        'ALTER TABLE messages ADD COLUMN media_size_bytes BIGINT NULL AFTER media_mime_type',
        'messages.media_size_bytes'
      );
    }

    if (!(await columnExists('media_file_name'))) {
      await safeAlter(
        'ALTER TABLE messages ADD COLUMN media_file_name VARCHAR(255) NULL AFTER media_size_bytes',
        'messages.media_file_name'
      );
    }

    if (!(await columnExists('thumbnail_key'))) {
      await safeAlter(
        'ALTER TABLE messages ADD COLUMN thumbnail_key VARCHAR(1000) NULL AFTER media_file_name',
        'messages.thumbnail_key'
      );
    }

    if (!(await columnExists('location_lat'))) {
      await safeAlter(
        'ALTER TABLE messages ADD COLUMN location_lat DECIMAL(10,7) NULL AFTER thumbnail_key',
        'messages.location_lat'
      );
    }

    if (!(await columnExists('location_lng'))) {
      await safeAlter(
        'ALTER TABLE messages ADD COLUMN location_lng DECIMAL(10,7) NULL AFTER location_lat',
        'messages.location_lng'
      );
    }

    if (!(await columnExists('location_label'))) {
      await safeAlter(
        'ALTER TABLE messages ADD COLUMN location_label VARCHAR(255) NULL AFTER location_lng',
        'messages.location_label'
      );
    }

    if (!(await columnExists('delivered_at'))) {
      await safeAlter(
        'ALTER TABLE messages ADD COLUMN delivered_at DATETIME NULL AFTER message',
        'messages.delivered_at'
      );
    }

    if (!(await columnExists('read_at'))) {
      await safeAlter(
        'ALTER TABLE messages ADD COLUMN read_at DATETIME NULL AFTER delivered_at',
        'messages.read_at'
      );
    }

    if (!(await indexExists('idx_messages_receiver_delivered'))) {
      await safeAlter(
        'ALTER TABLE messages ADD KEY idx_messages_receiver_delivered (receiver_id, delivered_at)',
        'idx_messages_receiver_delivered'
      );
    }

    if (!(await indexExists('idx_messages_receiver_read'))) {
      await safeAlter(
        'ALTER TABLE messages ADD KEY idx_messages_receiver_read (receiver_id, read_at)',
        'idx_messages_receiver_read'
      );
    }

    if (!(await indexExists('idx_messages_shipment_receiver_read'))) {
      await safeAlter(
        'ALTER TABLE messages ADD KEY idx_messages_shipment_receiver_read (shipment_id, receiver_id, read_at)',
        'idx_messages_shipment_receiver_read'
      );
    }

    if (!(await indexExists('idx_messages_type_created'))) {
      await safeAlter(
        'ALTER TABLE messages ADD KEY idx_messages_type_created (message_type, created_at)',
        'idx_messages_type_created'
      );
    }
  })().catch((error) => {
    ensurePromise = null;
    throw error;
  });

  return ensurePromise;
}

module.exports = { ensureMessageStatusSchema };
