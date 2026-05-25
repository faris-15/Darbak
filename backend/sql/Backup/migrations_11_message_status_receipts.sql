-- Add one-to-one chat delivery/read receipts.
-- Version-safe for MySQL/MariaDB instances that do not support IF NOT EXISTS.

SET @message_delivered_column_exists := (
  SELECT COUNT(*)
  FROM INFORMATION_SCHEMA.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'messages'
    AND COLUMN_NAME = 'delivered_at'
);

SET @message_delivered_column_sql := IF(
  @message_delivered_column_exists = 0,
  'ALTER TABLE messages ADD COLUMN delivered_at DATETIME NULL AFTER message',
  'SELECT 1'
);

PREPARE message_delivered_column_stmt FROM @message_delivered_column_sql;
EXECUTE message_delivered_column_stmt;
DEALLOCATE PREPARE message_delivered_column_stmt;

SET @message_read_column_exists := (
  SELECT COUNT(*)
  FROM INFORMATION_SCHEMA.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'messages'
    AND COLUMN_NAME = 'read_at'
);

SET @message_read_column_sql := IF(
  @message_read_column_exists = 0,
  'ALTER TABLE messages ADD COLUMN read_at DATETIME NULL AFTER delivered_at',
  'SELECT 1'
);

PREPARE message_read_column_stmt FROM @message_read_column_sql;
EXECUTE message_read_column_stmt;
DEALLOCATE PREPARE message_read_column_stmt;

SET @message_receiver_delivered_index_exists := (
  SELECT COUNT(*)
  FROM INFORMATION_SCHEMA.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'messages'
    AND INDEX_NAME = 'idx_messages_receiver_delivered'
);

SET @message_receiver_delivered_index_sql := IF(
  @message_receiver_delivered_index_exists = 0,
  'CREATE INDEX idx_messages_receiver_delivered ON messages (receiver_id, delivered_at)',
  'SELECT 1'
);

PREPARE message_receiver_delivered_index_stmt FROM @message_receiver_delivered_index_sql;
EXECUTE message_receiver_delivered_index_stmt;
DEALLOCATE PREPARE message_receiver_delivered_index_stmt;

SET @message_receiver_read_index_exists := (
  SELECT COUNT(*)
  FROM INFORMATION_SCHEMA.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'messages'
    AND INDEX_NAME = 'idx_messages_receiver_read'
);

SET @message_receiver_read_index_sql := IF(
  @message_receiver_read_index_exists = 0,
  'CREATE INDEX idx_messages_receiver_read ON messages (receiver_id, read_at)',
  'SELECT 1'
);

PREPARE message_receiver_read_index_stmt FROM @message_receiver_read_index_sql;
EXECUTE message_receiver_read_index_stmt;
DEALLOCATE PREPARE message_receiver_read_index_stmt;

SET @message_shipment_receiver_read_index_exists := (
  SELECT COUNT(*)
  FROM INFORMATION_SCHEMA.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'messages'
    AND INDEX_NAME = 'idx_messages_shipment_receiver_read'
);

SET @message_shipment_receiver_read_index_sql := IF(
  @message_shipment_receiver_read_index_exists = 0,
  'CREATE INDEX idx_messages_shipment_receiver_read ON messages (shipment_id, receiver_id, read_at)',
  'SELECT 1'
);

PREPARE message_shipment_receiver_read_index_stmt FROM @message_shipment_receiver_read_index_sql;
EXECUTE message_shipment_receiver_read_index_stmt;
DEALLOCATE PREPARE message_shipment_receiver_read_index_stmt;
