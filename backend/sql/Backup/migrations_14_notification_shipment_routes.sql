-- Add shipment references for notification route labels.
-- Version-safe for MySQL/MariaDB instances that do not support IF NOT EXISTS.

SET @notification_shipment_column_exists := (
  SELECT COUNT(*)
  FROM INFORMATION_SCHEMA.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'notifications'
    AND COLUMN_NAME = 'related_shipment_id'
);

SET @notification_shipment_column_sql := IF(
  @notification_shipment_column_exists = 0,
  'ALTER TABLE notifications ADD COLUMN related_shipment_id INT(11) NULL AFTER message',
  'SELECT 1'
);

PREPARE notification_shipment_column_stmt FROM @notification_shipment_column_sql;
EXECUTE notification_shipment_column_stmt;
DEALLOCATE PREPARE notification_shipment_column_stmt;

SET @notification_bid_column_exists := (
  SELECT COUNT(*)
  FROM INFORMATION_SCHEMA.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'notifications'
    AND COLUMN_NAME = 'related_bid_id'
);

SET @notification_bid_column_sql := IF(
  @notification_bid_column_exists = 0,
  'ALTER TABLE notifications ADD COLUMN related_bid_id INT(11) NULL AFTER related_shipment_id',
  'SELECT 1'
);

PREPARE notification_bid_column_stmt FROM @notification_bid_column_sql;
EXECUTE notification_bid_column_stmt;
DEALLOCATE PREPARE notification_bid_column_stmt;

SET @notification_shipment_index_exists := (
  SELECT COUNT(*)
  FROM INFORMATION_SCHEMA.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'notifications'
    AND INDEX_NAME = 'idx_notifications_user_shipment_created'
);

SET @notification_shipment_index_sql := IF(
  @notification_shipment_index_exists = 0,
  'ALTER TABLE notifications ADD KEY idx_notifications_user_shipment_created (user_id, related_shipment_id, created_at)',
  'SELECT 1'
);

PREPARE notification_shipment_index_stmt FROM @notification_shipment_index_sql;
EXECUTE notification_shipment_index_stmt;
DEALLOCATE PREPARE notification_shipment_index_stmt;
