-- Shipment truck requirements + operating card admin indexes

SET @has_req_group := (
  SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'shipments' AND COLUMN_NAME = 'required_truck_group'
);

SET @sql_ship_cols := IF(
  @has_req_group = 0,
  'ALTER TABLE shipments
     ADD COLUMN required_truck_group VARCHAR(32) NULL AFTER cargo_description,
     ADD COLUMN required_truck_category VARCHAR(64) NULL AFTER required_truck_group,
     ADD COLUMN required_axle_count TINYINT UNSIGNED NULL AFTER required_truck_category,
     ADD COLUMN required_body_type VARCHAR(64) NULL AFTER required_axle_count,
     ADD COLUMN required_min_capacity_tons DECIMAL(10,2) NULL AFTER required_body_type',
  'SELECT 1'
);
PREPARE stmt FROM @sql_ship_cols;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

CREATE INDEX IF NOT EXISTS idx_shipments_required_truck_group ON shipments (required_truck_group);
CREATE INDEX IF NOT EXISTS idx_shipments_required_truck_category ON shipments (required_truck_category);

CREATE INDEX IF NOT EXISTS idx_operating_cards_driver_status ON driver_operating_cards (driver_id, verification_status);
