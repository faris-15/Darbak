const pool = require('../config/db');

let ensurePromise = null;

async function columnExists(columnName) {
  const [rows] = await pool.execute(
    `SELECT COUNT(*) AS count
     FROM INFORMATION_SCHEMA.COLUMNS
     WHERE TABLE_SCHEMA = DATABASE()
       AND TABLE_NAME = 'notifications'
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
       AND TABLE_NAME = 'notifications'
       AND INDEX_NAME = ?`,
    [indexName]
  );
  return Number(rows[0]?.count || 0) > 0;
}

async function safeAlter(sql, label) {
  try {
    await pool.execute(sql);
  } catch (error) {
    if (error && ['ER_DUP_FIELDNAME', 'ER_DUP_KEYNAME'].includes(error.code)) {
      return;
    }
    console.error(`[NotificationSchema] Failed to apply ${label}:`, error.message);
    throw error;
  }
}

async function ensureNotificationShipmentSchema() {
  if (ensurePromise) return ensurePromise;

  ensurePromise = (async () => {
    if (!(await columnExists('related_shipment_id'))) {
      await safeAlter(
        'ALTER TABLE notifications ADD COLUMN related_shipment_id INT(11) NULL AFTER message',
        'notifications.related_shipment_id'
      );
    }

    if (!(await columnExists('related_bid_id'))) {
      await safeAlter(
        'ALTER TABLE notifications ADD COLUMN related_bid_id INT(11) NULL AFTER related_shipment_id',
        'notifications.related_bid_id'
      );
    }

    if (!(await indexExists('idx_notifications_user_shipment_created'))) {
      await safeAlter(
        'ALTER TABLE notifications ADD KEY idx_notifications_user_shipment_created (user_id, related_shipment_id, created_at)',
        'idx_notifications_user_shipment_created'
      );
    }
  })().catch((error) => {
    ensurePromise = null;
    throw error;
  });

  return ensurePromise;
}

function readOptionalInt(...values) {
  for (const value of values) {
    if (value === null || value === undefined || value === '') continue;
    const parsed = Number(value);
    if (Number.isInteger(parsed) && parsed > 0) return parsed;
  }
  return null;
}

function extractShipmentIdFromMessage(message) {
  const match = String(message || '').match(/(?:للشحنة|الشحنة)\s*(?:رقم)?\s*#?(\d+)/);
  return match ? readOptionalInt(match[1]) : null;
}

async function hydrateMissingRoutes(rows) {
  const missingShipmentIds = [
    ...new Set(
      rows
        .filter((row) => !row.route_description)
        .map((row) => extractShipmentIdFromMessage(row.message))
        .filter(Boolean)
    ),
  ];

  if (!missingShipmentIds.length) return rows;

  const placeholders = missingShipmentIds.map(() => '?').join(', ');
  const [shipments] = await pool.execute(
    `SELECT id, pickup_address, dropoff_address
     FROM shipments
     WHERE id IN (${placeholders})`,
    missingShipmentIds
  );
  const routeByShipmentId = new Map(
    shipments.map((shipment) => [
      Number(shipment.id),
      {
        pickup_city: shipment.pickup_address,
        dropoff_city: shipment.dropoff_address,
        route_description:
          shipment.pickup_address && shipment.dropoff_address
            ? `${shipment.pickup_address} إلى ${shipment.dropoff_address}`
            : null,
      },
    ])
  );

  return rows.map((row) => {
    if (row.route_description) return row;
    const fallbackShipmentId = extractShipmentIdFromMessage(row.message);
    const route = routeByShipmentId.get(Number(fallbackShipmentId));
    if (!route) return row;
    return {
      ...row,
      related_shipment_id: row.related_shipment_id ?? fallbackShipmentId,
      shipment_id: row.shipment_id ?? fallbackShipmentId,
      pickup_city: route.pickup_city,
      dropoff_city: route.dropoff_city,
      route_description: route.route_description,
    };
  });
}

const Notification = {
  create: async ({
    user_id,
    userId,
    title,
    message,
    is_read = 0,
    related_shipment_id,
    relatedShipmentId,
    shipment_id,
    shipmentId,
    related_bid_id,
    relatedBidId,
    bid_id,
    bidId,
  }) => {
    await ensureNotificationShipmentSchema();
    const resolvedUserId = user_id ?? userId;
    const resolvedShipmentId = readOptionalInt(
      related_shipment_id,
      relatedShipmentId,
      shipment_id,
      shipmentId
    );
    const resolvedBidId = readOptionalInt(
      related_bid_id,
      relatedBidId,
      bid_id,
      bidId
    );

    const [result] = await pool.execute(
      `INSERT INTO notifications
       (user_id, title, message, related_shipment_id, related_bid_id, is_read)
       VALUES (?, ?, ?, ?, ?, ?)`,
      [resolvedUserId, title, message, resolvedShipmentId, resolvedBidId, is_read]
    );
    return {
      id: result.insertId,
      user_id: resolvedUserId,
      title,
      message,
      related_shipment_id: resolvedShipmentId,
      shipment_id: resolvedShipmentId,
      related_bid_id: resolvedBidId,
      is_read,
      created_at: new Date(),
    };
  },

  findByUserId: async (user_id, unreadOnly = false) => {
    await ensureNotificationShipmentSchema();

    let query = `
      SELECT
        n.*,
        n.related_shipment_id AS shipment_id,
        s.pickup_address AS pickup_city,
        s.dropoff_address AS dropoff_city,
        CASE
          WHEN s.pickup_address IS NOT NULL AND s.dropoff_address IS NOT NULL
          THEN CONCAT(s.pickup_address, ' إلى ', s.dropoff_address)
          ELSE NULL
        END AS route_description
      FROM notifications n
      LEFT JOIN shipments s ON s.id = n.related_shipment_id
      WHERE n.user_id = ?`;
    const params = [user_id];

    if (unreadOnly) {
      query += ' AND n.is_read = 0';
    }

    query += ' ORDER BY n.created_at DESC LIMIT 50';

    const [rows] = await pool.execute(query, params);
    return hydrateMissingRoutes(rows);
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
