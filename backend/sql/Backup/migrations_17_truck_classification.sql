-- Truck classification normalization (category, axles, body, capacity)
-- Safe to run multiple times on environments that already applied runtime schema helper.

SET @has_category := (
  SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'trucks' AND COLUMN_NAME = 'category'
);

SET @sql_add_cols := IF(
  @has_category = 0,
  'ALTER TABLE trucks
     ADD COLUMN category VARCHAR(64) NULL AFTER truck_type,
     ADD COLUMN axle_count TINYINT UNSIGNED NULL AFTER category,
     ADD COLUMN body_type VARCHAR(64) NULL AFTER axle_count,
     ADD COLUMN payload_capacity VARCHAR(32) NULL AFTER body_type,
     ADD COLUMN max_weight_tons DECIMAL(10,2) NULL AFTER payload_capacity',
  'SELECT 1'
);
PREPARE stmt FROM @sql_add_cols;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

ALTER TABLE trucks MODIFY truck_type VARCHAR(255) NULL;

UPDATE trucks SET
  category = 'light_single_1_3',
  axle_count = 1,
  body_type = 'standard_cargo',
  payload_capacity = '1_3',
  max_weight_tons = 2,
  capacity_kg = CASE WHEN capacity_kg IS NULL OR capacity_kg = 0 THEN 2000 ELSE capacity_kg END,
  truck_type = COALESCE(NULLIF(truck_type, ''), 'دباب نقل — محور واحد')
WHERE truck_type = 'دباب نقل' AND (category IS NULL OR category = '');

UPDATE trucks SET
  category = 'light_single_3_5',
  axle_count = 1,
  body_type = 'open_bed',
  payload_capacity = '3_5',
  max_weight_tons = 4,
  capacity_kg = CASE WHEN capacity_kg IS NULL OR capacity_kg = 0 THEN 4000 ELSE capacity_kg END,
  truck_type = COALESCE(NULLIF(truck_type, ''), 'وانيت — محور واحد')
WHERE truck_type = 'وانيت' AND (category IS NULL OR category = '');

UPDATE trucks SET
  category = 'medium_double_5_10',
  axle_count = 2,
  body_type = 'box',
  payload_capacity = '5_10',
  max_weight_tons = 7.5,
  capacity_kg = CASE WHEN capacity_kg IS NULL OR capacity_kg = 0 THEN 7500 ELSE capacity_kg END,
  truck_type = COALESCE(NULLIF(truck_type, ''), 'دينا — محوران')
WHERE truck_type = 'دينا' AND (category IS NULL OR category = '');

UPDATE trucks SET
  category = 'medium_double_10_15',
  axle_count = 2,
  body_type = 'box',
  payload_capacity = '10_15',
  max_weight_tons = 12.5,
  capacity_kg = CASE WHEN capacity_kg IS NULL OR capacity_kg = 0 THEN 12500 ELSE capacity_kg END,
  truck_type = COALESCE(NULLIF(truck_type, ''), 'لوري — محوران')
WHERE truck_type = 'لوري' AND (category IS NULL OR category = '');

UPDATE trucks SET
  category = 'spec_car_carrier',
  axle_count = 2,
  body_type = 'car_carrier',
  payload_capacity = 'var_8_12',
  max_weight_tons = 10,
  capacity_kg = CASE WHEN capacity_kg IS NULL OR capacity_kg = 0 THEN 10000 ELSE capacity_kg END,
  truck_type = COALESCE(NULLIF(truck_type, ''), 'سطحة')
WHERE truck_type = 'سطحة' AND (category IS NULL OR category = '');

UPDATE trucks SET
  category = 'heavy_flatbed_trailer_25_40',
  axle_count = 3,
  body_type = 'flatbed',
  payload_capacity = '30_35',
  max_weight_tons = 32.5,
  capacity_kg = CASE WHEN capacity_kg IS NULL OR capacity_kg = 0 THEN 32500 ELSE capacity_kg END,
  truck_type = COALESCE(NULLIF(truck_type, ''), 'تريلا جوانب')
WHERE truck_type = 'تريلا جوانب' AND (category IS NULL OR category = '');

UPDATE trucks SET
  category = 'heavy_curtain_trailer_25_40',
  axle_count = 3,
  body_type = 'curtain_side',
  payload_capacity = '30_35',
  max_weight_tons = 32.5,
  capacity_kg = CASE WHEN capacity_kg IS NULL OR capacity_kg = 0 THEN 32500 ELSE capacity_kg END,
  truck_type = COALESCE(NULLIF(truck_type, ''), 'تريلا ستارة')
WHERE truck_type = 'تريلا ستارة' AND (category IS NULL OR category = '');

UPDATE trucks SET
  category = 'heavy_reefer_trailer_20_35',
  axle_count = 3,
  body_type = 'refrigerated',
  payload_capacity = '25_30',
  max_weight_tons = 27.5,
  capacity_kg = CASE WHEN capacity_kg IS NULL OR capacity_kg = 0 THEN 27500 ELSE capacity_kg END,
  truck_type = COALESCE(NULLIF(truck_type, ''), 'برادة')
WHERE truck_type = 'برادة' AND (category IS NULL OR category = '');

UPDATE trucks SET
  category = 'heavy_tanker_variable',
  axle_count = 3,
  body_type = 'tanker',
  payload_capacity = '20_30',
  max_weight_tons = 25,
  capacity_kg = CASE WHEN capacity_kg IS NULL OR capacity_kg = 0 THEN 25000 ELSE capacity_kg END,
  truck_type = COALESCE(NULLIF(truck_type, ''), 'صهريج')
WHERE truck_type = 'صهريج' AND (category IS NULL OR category = '');

UPDATE trucks SET
  category = 'heavy_dump_20_40',
  axle_count = 3,
  body_type = 'dump',
  payload_capacity = '25_30',
  max_weight_tons = 27.5,
  capacity_kg = CASE WHEN capacity_kg IS NULL OR capacity_kg = 0 THEN 27500 ELSE capacity_kg END,
  truck_type = COALESCE(NULLIF(truck_type, ''), 'قلاب')
WHERE truck_type = 'قلاب' AND (category IS NULL OR category = '');

UPDATE trucks SET
  category = 'heavy_reefer_trailer_20_35',
  axle_count = 3,
  body_type = 'refrigerated',
  payload_capacity = '20_25',
  max_weight_tons = 22.5,
  capacity_kg = CASE WHEN capacity_kg IS NULL OR capacity_kg = 0 THEN 22500 ELSE capacity_kg END,
  truck_type = COALESCE(NULLIF(truck_type, ''), 'مبرد')
WHERE truck_type = 'مبرد' AND (category IS NULL OR category = '');

UPDATE trucks SET
  category = 'medium_double_5_10',
  axle_count = COALESCE(axle_count, 2),
  body_type = COALESCE(body_type, 'box'),
  payload_capacity = COALESCE(payload_capacity, '5_10'),
  max_weight_tons = COALESCE(max_weight_tons, 7.5),
  capacity_kg = CASE WHEN capacity_kg IS NULL OR capacity_kg = 0 THEN 7500 ELSE capacity_kg END,
  truck_type = COALESCE(NULLIF(truck_type, ''), 'شاحنة — بيانات قديمة')
WHERE category IS NULL OR category = '';

ALTER TABLE trucks
  MODIFY category VARCHAR(64) NOT NULL DEFAULT 'legacy_unknown',
  MODIFY axle_count TINYINT UNSIGNED NOT NULL DEFAULT 2,
  MODIFY body_type VARCHAR(64) NOT NULL DEFAULT 'standard_cargo',
  MODIFY payload_capacity VARCHAR(32) NOT NULL DEFAULT '5_10',
  MODIFY max_weight_tons DECIMAL(10,2) NOT NULL DEFAULT 7.50;

CREATE INDEX IF NOT EXISTS idx_trucks_category ON trucks (category);
CREATE INDEX IF NOT EXISTS idx_trucks_max_weight ON trucks (max_weight_tons);
