-- Add auction timing fields to shipments
ALTER TABLE shipments
ADD COLUMN auction_duration_hours INT DEFAULT 24,
ADD COLUMN auction_end_time DATETIME NULL;

-- Extend trucks with Saudi registration support
ALTER TABLE trucks
ADD COLUMN isthimara_no TEXT NULL,
ADD COLUMN is_active TINYINT(1) NOT NULL DEFAULT 0;

-- Ensure plate uniqueness system-wide
ALTER TABLE trucks
ADD CONSTRAINT uniq_trucks_plate_number UNIQUE (plate_number);

-- Create shipment-scoped messages table for chat
CREATE TABLE IF NOT EXISTS messages (
  id INT AUTO_INCREMENT PRIMARY KEY,
  shipment_id INT NOT NULL,
  sender_id INT NOT NULL,
  receiver_id INT NOT NULL,
  message TEXT NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (shipment_id) REFERENCES shipments(id) ON DELETE CASCADE,
  FOREIGN KEY (sender_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (receiver_id) REFERENCES users(id) ON DELETE CASCADE,
  INDEX idx_messages_shipment_created (shipment_id, created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
