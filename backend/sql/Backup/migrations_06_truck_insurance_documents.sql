-- Link insurance compliance documents to the specific truck they belong to.
-- The backend also applies this safely at runtime for local/dev databases.
SET @db_name := DATABASE();

SET @add_truck_id := (
  SELECT IF(
    COUNT(*) = 0,
    'ALTER TABLE compliance_documents ADD COLUMN truck_id INT(11) NULL AFTER user_id',
    'SELECT 1'
  )
  FROM INFORMATION_SCHEMA.COLUMNS
  WHERE TABLE_SCHEMA = @db_name
    AND TABLE_NAME = 'compliance_documents'
    AND COLUMN_NAME = 'truck_id'
);
PREPARE stmt FROM @add_truck_id;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @add_truck_idx := (
  SELECT IF(
    COUNT(*) = 0,
    'ALTER TABLE compliance_documents ADD KEY idx_truck_id (truck_id)',
    'SELECT 1'
  )
  FROM INFORMATION_SCHEMA.STATISTICS
  WHERE TABLE_SCHEMA = @db_name
    AND TABLE_NAME = 'compliance_documents'
    AND INDEX_NAME = 'idx_truck_id'
);
PREPARE stmt FROM @add_truck_idx;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @add_truck_type_idx := (
  SELECT IF(
    COUNT(*) = 0,
    'ALTER TABLE compliance_documents ADD KEY idx_truck_document_type (truck_id, document_type)',
    'SELECT 1'
  )
  FROM INFORMATION_SCHEMA.STATISTICS
  WHERE TABLE_SCHEMA = @db_name
    AND TABLE_NAME = 'compliance_documents'
    AND INDEX_NAME = 'idx_truck_document_type'
);
PREPARE stmt FROM @add_truck_type_idx;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @add_truck_fk := (
  SELECT IF(
    COUNT(*) = 0,
    'ALTER TABLE compliance_documents ADD CONSTRAINT compliance_documents_truck_fk FOREIGN KEY (truck_id) REFERENCES trucks (id) ON DELETE CASCADE',
    'SELECT 1'
  )
  FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS
  WHERE TABLE_SCHEMA = @db_name
    AND TABLE_NAME = 'compliance_documents'
    AND CONSTRAINT_NAME = 'compliance_documents_truck_fk'
);
PREPARE stmt FROM @add_truck_fk;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
