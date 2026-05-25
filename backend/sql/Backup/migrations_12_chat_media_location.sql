-- Add rich chat message support for images, videos, and locations.
-- Version-safe for MySQL/MariaDB instances that do not support ADD COLUMN IF NOT EXISTS.

SET @message_type_column_exists := (
  SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'messages'
    AND COLUMN_NAME = 'message_type'
);
SET @message_type_column_sql := IF(
  @message_type_column_exists = 0,
  'ALTER TABLE messages ADD COLUMN message_type ENUM(''text'', ''image'', ''video'', ''location'') NOT NULL DEFAULT ''text'' AFTER receiver_id',
  'SELECT 1'
);
PREPARE message_type_column_stmt FROM @message_type_column_sql;
EXECUTE message_type_column_stmt;
DEALLOCATE PREPARE message_type_column_stmt;

SET @media_key_column_exists := (
  SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'messages'
    AND COLUMN_NAME = 'media_key'
);
SET @media_key_column_sql := IF(
  @media_key_column_exists = 0,
  'ALTER TABLE messages ADD COLUMN media_key VARCHAR(1000) NULL AFTER message',
  'SELECT 1'
);
PREPARE media_key_column_stmt FROM @media_key_column_sql;
EXECUTE media_key_column_stmt;
DEALLOCATE PREPARE media_key_column_stmt;

SET @media_mime_column_exists := (
  SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'messages'
    AND COLUMN_NAME = 'media_mime_type'
);
SET @media_mime_column_sql := IF(
  @media_mime_column_exists = 0,
  'ALTER TABLE messages ADD COLUMN media_mime_type VARCHAR(120) NULL AFTER media_key',
  'SELECT 1'
);
PREPARE media_mime_column_stmt FROM @media_mime_column_sql;
EXECUTE media_mime_column_stmt;
DEALLOCATE PREPARE media_mime_column_stmt;

SET @media_size_column_exists := (
  SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'messages'
    AND COLUMN_NAME = 'media_size_bytes'
);
SET @media_size_column_sql := IF(
  @media_size_column_exists = 0,
  'ALTER TABLE messages ADD COLUMN media_size_bytes BIGINT NULL AFTER media_mime_type',
  'SELECT 1'
);
PREPARE media_size_column_stmt FROM @media_size_column_sql;
EXECUTE media_size_column_stmt;
DEALLOCATE PREPARE media_size_column_stmt;

SET @media_name_column_exists := (
  SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'messages'
    AND COLUMN_NAME = 'media_file_name'
);
SET @media_name_column_sql := IF(
  @media_name_column_exists = 0,
  'ALTER TABLE messages ADD COLUMN media_file_name VARCHAR(255) NULL AFTER media_size_bytes',
  'SELECT 1'
);
PREPARE media_name_column_stmt FROM @media_name_column_sql;
EXECUTE media_name_column_stmt;
DEALLOCATE PREPARE media_name_column_stmt;

SET @thumbnail_key_column_exists := (
  SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'messages'
    AND COLUMN_NAME = 'thumbnail_key'
);
SET @thumbnail_key_column_sql := IF(
  @thumbnail_key_column_exists = 0,
  'ALTER TABLE messages ADD COLUMN thumbnail_key VARCHAR(1000) NULL AFTER media_file_name',
  'SELECT 1'
);
PREPARE thumbnail_key_column_stmt FROM @thumbnail_key_column_sql;
EXECUTE thumbnail_key_column_stmt;
DEALLOCATE PREPARE thumbnail_key_column_stmt;

SET @location_lat_column_exists := (
  SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'messages'
    AND COLUMN_NAME = 'location_lat'
);
SET @location_lat_column_sql := IF(
  @location_lat_column_exists = 0,
  'ALTER TABLE messages ADD COLUMN location_lat DECIMAL(10,7) NULL AFTER thumbnail_key',
  'SELECT 1'
);
PREPARE location_lat_column_stmt FROM @location_lat_column_sql;
EXECUTE location_lat_column_stmt;
DEALLOCATE PREPARE location_lat_column_stmt;

SET @location_lng_column_exists := (
  SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'messages'
    AND COLUMN_NAME = 'location_lng'
);
SET @location_lng_column_sql := IF(
  @location_lng_column_exists = 0,
  'ALTER TABLE messages ADD COLUMN location_lng DECIMAL(10,7) NULL AFTER location_lat',
  'SELECT 1'
);
PREPARE location_lng_column_stmt FROM @location_lng_column_sql;
EXECUTE location_lng_column_stmt;
DEALLOCATE PREPARE location_lng_column_stmt;

SET @location_label_column_exists := (
  SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'messages'
    AND COLUMN_NAME = 'location_label'
);
SET @location_label_column_sql := IF(
  @location_label_column_exists = 0,
  'ALTER TABLE messages ADD COLUMN location_label VARCHAR(255) NULL AFTER location_lng',
  'SELECT 1'
);
PREPARE location_label_column_stmt FROM @location_label_column_sql;
EXECUTE location_label_column_stmt;
DEALLOCATE PREPARE location_label_column_stmt;

SET @message_type_created_index_exists := (
  SELECT COUNT(*) FROM INFORMATION_SCHEMA.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'messages'
    AND INDEX_NAME = 'idx_messages_type_created'
);
SET @message_type_created_index_sql := IF(
  @message_type_created_index_exists = 0,
  'CREATE INDEX idx_messages_type_created ON messages (message_type, created_at)',
  'SELECT 1'
);
PREPARE message_type_created_index_stmt FROM @message_type_created_index_sql;
EXECUTE message_type_created_index_stmt;
DEALLOCATE PREPARE message_type_created_index_stmt;
