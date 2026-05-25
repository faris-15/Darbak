-- Optional additive migration: device tokens for FCM and generated trip contracts.
-- Run manually against your database when you enable push notifications and PDF contracts.

-- If fcm_token already exists, skip this line (MySQL will error once).
ALTER TABLE users ADD COLUMN fcm_token VARCHAR(512) NULL;

CREATE TABLE IF NOT EXISTS contracts (
  id INT(11) NOT NULL AUTO_INCREMENT,
  shipment_id INT(11) NOT NULL,
  bid_id INT(11) NOT NULL,
  driver_id INT(11) NOT NULL,
  shipper_id INT(11) NOT NULL,
  pdf_key VARCHAR(512) NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uniq_contract_shipment (shipment_id),
  KEY idx_contracts_bid (bid_id),
  CONSTRAINT fk_contracts_shipment FOREIGN KEY (shipment_id) REFERENCES shipments (id) ON DELETE CASCADE,
  CONSTRAINT fk_contracts_bid FOREIGN KEY (bid_id) REFERENCES bids (id) ON DELETE CASCADE,
  CONSTRAINT fk_contracts_driver FOREIGN KEY (driver_id) REFERENCES users (id) ON DELETE CASCADE,
  CONSTRAINT fk_contracts_shipper FOREIGN KEY (shipper_id) REFERENCES users (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
