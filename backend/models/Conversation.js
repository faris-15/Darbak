const pool = require('../config/db');

const DIRECT_CONVERSATION_TYPE = 'direct';

const tableExists = async (tableName) => {
  const [rows] = await pool.execute(
    `SELECT COUNT(*) AS count
     FROM INFORMATION_SCHEMA.TABLES
     WHERE TABLE_SCHEMA = DATABASE()
       AND TABLE_NAME = ?`,
    [tableName]
  );
  return Number(rows[0]?.count || 0) > 0;
};

const columnExists = async (tableName, columnName) => {
  const [rows] = await pool.execute(
    `SELECT COUNT(*) AS count
     FROM INFORMATION_SCHEMA.COLUMNS
     WHERE TABLE_SCHEMA = DATABASE()
       AND TABLE_NAME = ?
       AND COLUMN_NAME = ?`,
    [tableName, columnName]
  );
  return Number(rows[0]?.count || 0) > 0;
};

const indexExists = async (tableName, indexName) => {
  const [rows] = await pool.execute(
    `SELECT COUNT(*) AS count
     FROM INFORMATION_SCHEMA.STATISTICS
     WHERE TABLE_SCHEMA = DATABASE()
       AND TABLE_NAME = ?
       AND INDEX_NAME = ?`,
    [tableName, indexName]
  );
  return Number(rows[0]?.count || 0) > 0;
};

const ensureConversationSchema = async () => {
  if (!(await tableExists('conversations'))) {
    await pool.execute(
      `CREATE TABLE conversations (
        id INT(11) NOT NULL AUTO_INCREMENT,
        shipment_id INT(11) NULL,
        sender_id INT(11) NULL,
        receiver_id INT(11) NULL,
        message TEXT NULL,
        conversation_key VARCHAR(64) NULL,
        type ENUM('direct', 'group') NOT NULL DEFAULT 'direct',
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (id),
        KEY idx_conversations_shipment_created (shipment_id, created_at),
        UNIQUE KEY uq_conversations_direct_key (conversation_key)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4`
    );
  } else {
    if (!(await columnExists('conversations', 'conversation_key'))) {
      await pool.execute('ALTER TABLE conversations ADD COLUMN conversation_key VARCHAR(64) NULL');
    }
    if (!(await columnExists('conversations', 'type'))) {
      await pool.execute(
        "ALTER TABLE conversations ADD COLUMN type ENUM('direct', 'group') NOT NULL DEFAULT 'direct'"
      );
    }
    if (!(await indexExists('conversations', 'uq_conversations_direct_key'))) {
      await pool.execute('ALTER TABLE conversations ADD UNIQUE KEY uq_conversations_direct_key (conversation_key)');
    }
  }

  await pool.execute(
    `CREATE TABLE IF NOT EXISTS conversation_participants (
      conversation_id INT(11) NOT NULL,
      user_id INT(11) NOT NULL,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      PRIMARY KEY (conversation_id, user_id),
      KEY idx_conversation_participants_user (user_id, conversation_id),
      CONSTRAINT conversation_participants_conversation_fk
        FOREIGN KEY (conversation_id) REFERENCES conversations(id) ON DELETE CASCADE,
      CONSTRAINT conversation_participants_user_fk
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4`
  );
};

const directConversationKey = (senderId, receiverId) => {
  const userA = Math.min(Number(senderId), Number(receiverId));
  const userB = Math.max(Number(senderId), Number(receiverId));
  return `${userA}:${userB}`;
};

const Conversation = {
  create: async ({ shipmentId, senderId, receiverId, message }) => {
    await ensureConversationSchema();
    const [result] = await pool.execute(
      'INSERT INTO conversations (shipment_id, sender_id, receiver_id, message) VALUES (?, ?, ?, ?)',
      [shipmentId, senderId, receiverId, message]
    );
    return { id: result.insertId, shipmentId, senderId, receiverId, message };
  },

  findByShipment: async (shipmentId) => {
    await ensureConversationSchema();
    const [rows] = await pool.execute('SELECT * FROM conversations WHERE shipment_id = ? ORDER BY created_at ASC', [shipmentId]);
    return rows;
  },

  deleteByShipment: async (shipmentId) => {
    await ensureConversationSchema();
    const [result] = await pool.execute(
      'DELETE FROM conversations WHERE shipment_id = ?',
      [shipmentId]
    );
    return result.affectedRows;
  },

  findDirectByUsers: async (senderId, receiverId) => {
    await ensureConversationSchema();
    const [rows] = await pool.execute(
      `SELECT cp.conversation_id
       FROM conversation_participants cp
       WHERE cp.user_id IN (?, ?)
       GROUP BY cp.conversation_id
       HAVING COUNT(DISTINCT cp.user_id) = 2
          AND (
            SELECT COUNT(*)
            FROM conversation_participants cp2
            WHERE cp2.conversation_id = cp.conversation_id
          ) = 2
       LIMIT 1`,
      [senderId, receiverId]
    );
    return rows[0]?.conversation_id || null;
  },

  getOrCreateDirect: async ({ senderId, receiverId }) => {
    await ensureConversationSchema();
    const conversationKey = directConversationKey(senderId, receiverId);
    const conn = await pool.getConnection();

    try {
      await conn.beginTransaction();

      const [existing] = await conn.execute(
        `SELECT id AS conversation_id
         FROM conversations
         WHERE conversation_key = ?
         LIMIT 1`,
        [conversationKey]
      );

      if (existing.length > 0) {
        await conn.commit();
        return {
          conversation_id: existing[0].conversation_id,
          created: false,
        };
      }

      const [created] = await conn.execute(
        `INSERT INTO conversations (conversation_key, type)
         VALUES (?, ?)`,
        [conversationKey, DIRECT_CONVERSATION_TYPE]
      );
      const conversationId = created.insertId;

      await conn.execute(
        `INSERT INTO conversation_participants (conversation_id, user_id)
         VALUES (?, ?), (?, ?)`,
        [conversationId, senderId, conversationId, receiverId]
      );

      await conn.commit();
      return { conversation_id: conversationId, created: true };
    } catch (error) {
      await conn.rollback();

      if (error.code === 'ER_DUP_ENTRY') {
        const [rows] = await pool.execute(
          `SELECT id AS conversation_id
           FROM conversations
           WHERE conversation_key = ?
           LIMIT 1`,
          [conversationKey]
        );
        if (rows.length > 0) {
          return {
            conversation_id: rows[0].conversation_id,
            created: false,
          };
        }
      }

      throw error;
    } finally {
      conn.release();
    }
  },
};

module.exports = Conversation;