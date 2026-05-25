-- Late delivery penalty: final deadline, stored penalty, one-time driver push flag.
-- Run against your Darbak database (e.g. darbak_db).

ALTER TABLE shipments
  ADD COLUMN final_delivery_date DATETIME NULL AFTER expected_delivery_date,
  ADD COLUMN penalty_amount DECIMAL(10,2) NOT NULL DEFAULT 0 AFTER final_price,
  ADD COLUMN late_penalty_push_sent TINYINT(1) NOT NULL DEFAULT 0 AFTER penalty_amount;

UPDATE shipments
SET final_delivery_date = expected_delivery_date
WHERE final_delivery_date IS NULL;
