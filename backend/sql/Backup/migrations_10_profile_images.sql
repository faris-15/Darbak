-- Add profile image support for driver and company accounts.
-- Version-safe for MySQL/MariaDB instances that do not support ADD COLUMN IF NOT EXISTS.

SET @profile_image_column_exists := (
  SELECT COUNT(*)
  FROM INFORMATION_SCHEMA.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'users'
    AND COLUMN_NAME = 'profile_image_url'
);

SET @profile_image_column_sql := IF(
  @profile_image_column_exists = 0,
  'ALTER TABLE users ADD COLUMN profile_image_url VARCHAR(1000) NULL AFTER document_path',
  'SELECT 1'
);

PREPARE profile_image_column_stmt FROM @profile_image_column_sql;
EXECUTE profile_image_column_stmt;
DEALLOCATE PREPARE profile_image_column_stmt;
