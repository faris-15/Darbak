ALTER TABLE shipments
MODIFY COLUMN status ENUM(
  'pending',
  'bidding',
  'assigned',
  'at_pickup',
  'en_route',
  'at_dropoff',
  'delivered',
  'cancelled'
) DEFAULT 'pending';

CREATE TABLE IF NOT EXISTS shipment_status_history (
  id INT(11) NOT NULL AUTO_INCREMENT,
  shipment_id INT(11) NOT NULL,
  status ENUM('assigned', 'at_pickup', 'en_route', 'at_dropoff', 'delivered') NOT NULL,
  location_lat DECIMAL(10,7) NULL,
  location_lng DECIMAL(10,7) NULL,
  photo_path VARCHAR(500) NULL,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  INDEX idx_shipment_updated (shipment_id, updated_at),
  CONSTRAINT fk_status_history_shipment
    FOREIGN KEY (shipment_id) REFERENCES shipments(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
