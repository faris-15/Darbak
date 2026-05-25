CREATE TABLE IF NOT EXISTS conversations (
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
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

SET @conversation_key_column_exists := (
  SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'conversations'
    AND COLUMN_NAME = 'conversation_key'
);
SET @conversation_key_column_sql := IF(
  @conversation_key_column_exists = 0,
  'ALTER TABLE conversations ADD COLUMN conversation_key VARCHAR(64) NULL',
  'SELECT 1'
);
PREPARE conversation_key_column_stmt FROM @conversation_key_column_sql;
EXECUTE conversation_key_column_stmt;
DEALLOCATE PREPARE conversation_key_column_stmt;

SET @conversation_type_column_exists := (
  SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'conversations'
    AND COLUMN_NAME = 'type'
);
SET @conversation_type_column_sql := IF(
  @conversation_type_column_exists = 0,
  'ALTER TABLE conversations ADD COLUMN type ENUM(''direct'', ''group'') NOT NULL DEFAULT ''direct''',
  'SELECT 1'
);
PREPARE conversation_type_column_stmt FROM @conversation_type_column_sql;
EXECUTE conversation_type_column_stmt;
DEALLOCATE PREPARE conversation_type_column_stmt;

SET @direct_key_index_exists := (
  SELECT COUNT(*) FROM INFORMATION_SCHEMA.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'conversations'
    AND INDEX_NAME = 'uq_conversations_direct_key'
);
SET @direct_key_index_sql := IF(
  @direct_key_index_exists = 0,
  'ALTER TABLE conversations ADD UNIQUE KEY uq_conversations_direct_key (conversation_key)',
  'SELECT 1'
);
PREPARE direct_key_index_stmt FROM @direct_key_index_sql;
EXECUTE direct_key_index_stmt;
DEALLOCATE PREPARE direct_key_index_stmt;

CREATE TABLE IF NOT EXISTS conversation_participants (
  conversation_id INT(11) NOT NULL,
  user_id INT(11) NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (conversation_id, user_id),
  KEY idx_conversation_participants_user (user_id, conversation_id),
  CONSTRAINT conversation_participants_conversation_fk
    FOREIGN KEY (conversation_id) REFERENCES conversations(id) ON DELETE CASCADE,
  CONSTRAINT conversation_participants_user_fk
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
