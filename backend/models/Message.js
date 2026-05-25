const pool = require('../config/db');
const { ensureProfileImageSchema } = require('../utils/profileImageSchema');
const { ensureMessageStatusSchema } = require('../utils/messageStatusSchema');

const normalizeMessageIds = (messageIds) => {
  if (!Array.isArray(messageIds)) return [];
  return [
    ...new Set(
      messageIds
        .map((id) => Number(id))
        .filter((id) => Number.isInteger(id) && id > 0)
    ),
  ];
};

const messageIdFilter = (messageIds, params) => {
  const ids = normalizeMessageIds(messageIds);
  if (!ids.length) return '';
  params.push(...ids);
  return ` AND id IN (${ids.map(() => '?').join(', ')})`;
};

const MESSAGE_TYPES = new Set(['text', 'image', 'video', 'location']);

const normalizeMessageType = (messageType) =>
  MESSAGE_TYPES.has(messageType) ? messageType : 'text';

const getReceiptRows = async (messageIds) => {
  const ids = normalizeMessageIds(messageIds);
  if (!ids.length) return [];
  await ensureMessageStatusSchema();
  const [rows] = await pool.execute(
    `SELECT id, shipment_id, sender_id, receiver_id, delivered_at, read_at
     FROM messages
     WHERE id IN (${ids.map(() => '?').join(', ')})`,
    ids
  );
  return rows;
};

const Message = {
  create: async ({
    shipmentId,
    senderId,
    receiverId,
    message = '',
    messageType = 'text',
    mediaKey = null,
    mediaMimeType = null,
    mediaSizeBytes = null,
    mediaFileName = null,
    thumbnailKey = null,
    locationLat = null,
    locationLng = null,
    locationLabel = null,
  }) => {
    await ensureMessageStatusSchema();
    const normalizedType = normalizeMessageType(messageType);
    const [result] = await pool.execute(
      `INSERT INTO messages (
         shipment_id,
         sender_id,
         receiver_id,
         message_type,
         message,
         media_key,
         media_mime_type,
         media_size_bytes,
         media_file_name,
         thumbnail_key,
         location_lat,
         location_lng,
         location_label
       ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        shipmentId,
        senderId,
        receiverId,
        normalizedType,
        message || '',
        mediaKey,
        mediaMimeType,
        mediaSizeBytes,
        mediaFileName,
        thumbnailKey,
        locationLat,
        locationLng,
        locationLabel,
      ]
    );
    return {
      id: result.insertId,
      shipment_id: shipmentId,
      sender_id: senderId,
      receiver_id: receiverId,
      message_type: normalizedType,
      message: message || '',
      media_key: mediaKey,
      media_mime_type: mediaMimeType,
      media_size_bytes: mediaSizeBytes,
      media_file_name: mediaFileName,
      thumbnail_key: thumbnailKey,
      location_lat: locationLat,
      location_lng: locationLng,
      location_label: locationLabel,
      delivered_at: null,
      read_at: null,
      created_at: new Date(),
    };
  },

  findById: async (messageId) => {
    await ensureProfileImageSchema();
    await ensureMessageStatusSchema();
    const [rows] = await pool.execute(
      `SELECT
         m.*,
         u.full_name AS sender_name,
         u.role AS sender_role,
         u.profile_image_url AS sender_profile_image_key
       FROM messages m
       LEFT JOIN users u ON u.id = m.sender_id
       WHERE m.id = ?
       LIMIT 1`,
      [messageId]
    );
    return rows[0] || null;
  },

  listByShipment: async (shipmentId) => {
    await ensureProfileImageSchema();
    await ensureMessageStatusSchema();
    const [rows] = await pool.execute(
      `SELECT
         m.*,
         u.full_name AS sender_name,
         u.role AS sender_role,
         u.profile_image_url AS sender_profile_image_key
       FROM messages m
       LEFT JOIN users u ON u.id = m.sender_id
       WHERE m.shipment_id = ?
       ORDER BY m.created_at ASC`,
      [shipmentId]
    );
    return rows;
  },

  /**
   * One row per other party, with the latest shipment-scoped message metadata.
   */
  listConversationSummariesForUser: async (userId) => {
    await ensureProfileImageSchema();
    await ensureMessageStatusSchema();
    const [rows] = await pool.execute(
      `SELECT
         latest.other_party_id,
         COALESCE(active_pair.shipment_id, m.shipment_id) AS shipment_id,
         m.message AS last_message,
         m.message_type AS last_message_type,
         m.media_mime_type AS last_media_mime_type,
         m.media_file_name AS last_media_file_name,
         m.location_label AS last_location_label,
         m.created_at AS last_message_at,
         m.sender_id AS last_sender_id,
         m.delivered_at AS last_delivered_at,
         m.read_at AS last_read_at,
         CASE
           WHEN m.message_type = 'video'
             OR LOWER(COALESCE(m.media_mime_type, '')) LIKE 'video/%'
             OR LOWER(COALESCE(m.media_file_name, '')) LIKE '%.mp4'
             OR LOWER(COALESCE(m.media_file_name, '')) LIKE '%.mov'
             OR LOWER(COALESCE(m.media_file_name, '')) LIKE '%.m4v' THEN 'فيديو'
           WHEN m.message_type = 'image' THEN 'صورة'
           WHEN m.message_type = 'location' THEN COALESCE(m.location_label, 'موقع')
           ELSE m.message
         END AS last_preview,
         COALESCE(unread.unread_count, 0) AS unread_count,
         s.pickup_address,
         s.dropoff_address,
         s.status,
         s.shipper_id,
         s.driver_id,
         u_other.full_name AS other_party_name,
         u_other.role AS other_party_role,
         u_other.profile_image_url AS other_party_profile_image_key
       FROM (
         SELECT other_party_id, MAX(message_id) AS mid
         FROM (
           SELECT
             m.id AS message_id,
             CASE
               WHEN s.shipper_id = ? THEN s.driver_id
               WHEN s.driver_id = ? THEN s.shipper_id
               WHEN m.sender_id = ? THEN m.receiver_id
               ELSE m.sender_id
             END AS other_party_id
           FROM messages m
           INNER JOIN shipments s ON s.id = m.shipment_id
           WHERE (m.sender_id = ? OR m.receiver_id = ?)
             AND s.status NOT IN ('delivered', 'cancelled')
         ) scoped_messages
         WHERE other_party_id IS NOT NULL
         GROUP BY other_party_id
       ) latest
       INNER JOIN messages m ON m.id = latest.mid
       INNER JOIN shipments s ON s.id = m.shipment_id
       LEFT JOIN (
         SELECT other_party_id, COUNT(*) AS unread_count
         FROM (
           SELECT
             CASE
               WHEN s.shipper_id = ? THEN s.driver_id
               WHEN s.driver_id = ? THEN s.shipper_id
               ELSE m.sender_id
             END AS other_party_id
           FROM messages m
           INNER JOIN shipments s ON s.id = m.shipment_id
           WHERE m.receiver_id = ? AND m.read_at IS NULL
         ) unread_messages
         WHERE other_party_id IS NOT NULL
         GROUP BY other_party_id
       ) unread ON unread.other_party_id = latest.other_party_id
       LEFT JOIN (
         SELECT other_party_id, MAX(shipment_id) AS shipment_id
         FROM (
           SELECT
             s.id AS shipment_id,
             CASE
               WHEN s.shipper_id = ? THEN s.driver_id
               WHEN s.driver_id = ? THEN s.shipper_id
             END AS other_party_id
           FROM shipments s
           WHERE (s.shipper_id = ? OR s.driver_id = ?)
             AND s.driver_id IS NOT NULL
             AND s.status IN ('assigned', 'at_pickup', 'en_route', 'at_dropoff', 'delivered')
         ) active_shipments
         WHERE other_party_id IS NOT NULL
         GROUP BY other_party_id
       ) active_pair ON active_pair.other_party_id = latest.other_party_id
       LEFT JOIN users u_other ON u_other.id = latest.other_party_id
       ORDER BY m.created_at DESC, m.id DESC`,
      [
        userId,
        userId,
        userId,
        userId,
        userId,
        userId,
        userId,
        userId,
        userId,
        userId,
        userId,
        userId,
      ]
    );
    return rows;
  },

  markDelivered: async ({ shipmentId, receiverId, messageIds = [] }) => {
    await ensureMessageStatusSchema();
    const selectParams = [shipmentId, receiverId];
    const idClause = messageIdFilter(messageIds, selectParams);
    const [pendingRows] = await pool.execute(
      `SELECT id
       FROM messages
       WHERE shipment_id = ?
         AND receiver_id = ?
         AND delivered_at IS NULL${idClause}`,
      selectParams
    );
    const ids = pendingRows.map((row) => row.id);
    if (!ids.length) return [];

    await pool.execute(
      `UPDATE messages
       SET delivered_at = COALESCE(delivered_at, ?)
       WHERE id IN (${ids.map(() => '?').join(', ')})`,
      [new Date(), ...ids]
    );
    return getReceiptRows(ids);
  },

  markRead: async ({ shipmentId, receiverId, messageIds = [] }) => {
    await ensureMessageStatusSchema();
    const selectParams = [shipmentId, receiverId];
    const idClause = messageIdFilter(messageIds, selectParams);
    const [pendingRows] = await pool.execute(
      `SELECT id
       FROM messages
       WHERE shipment_id = ?
         AND receiver_id = ?
         AND read_at IS NULL${idClause}`,
      selectParams
    );
    const ids = pendingRows.map((row) => row.id);
    if (!ids.length) return [];

    const now = new Date();
    await pool.execute(
      `UPDATE messages
       SET delivered_at = COALESCE(delivered_at, ?),
           read_at = COALESCE(read_at, ?)
       WHERE id IN (${ids.map(() => '?').join(', ')})`,
      [now, now, ...ids]
    );
    return getReceiptRows(ids);
  },

  deleteByShipment: async (shipmentId) => {
    const Conversation = require('./Conversation');
    await Conversation.deleteByShipment(shipmentId).catch((err) =>
      console.error('[Message.deleteByShipment] Conversation cleanup error:', err)
    );
    const [result] = await pool.execute(
      'DELETE FROM messages WHERE shipment_id = ?',
      [shipmentId]
    );
    return result.affectedRows;
  },
};

module.exports = Message;
