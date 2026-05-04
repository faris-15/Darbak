-- Darbak MySQL schema

CREATE DATABASE IF NOT EXISTS darbak_db;
USE darbak_db;

CREATE TABLE IF NOT EXISTS users (
    id INT(11) NOT NULL AUTO_INCREMENT,
    full_name VARCHAR(150) NOT NULL,
    email VARCHAR(150) NOT NULL UNIQUE,
    phone VARCHAR(15) NOT NULL UNIQUE,
    password VARCHAR(255) NOT NULL,
    role ENUM('driver', 'shipper', 'admin') NOT NULL DEFAULT 'driver',
    license_no VARCHAR(50) NULL,
    commercial_no VARCHAR(50) NULL,
    document_path VARCHAR(255) NULL,
    issue_date DATE NULL,
    expiry_date DATE NULL,
    verification_status ENUM('pending', 'verified', 'rejected') DEFAULT 'pending',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS shipments (
    id INT(11) NOT NULL AUTO_INCREMENT,
    shipper_id INT(11) NOT NULL,
    driver_id INT(11) NULL,
    weight_kg DECIMAL(10,2) NOT NULL,
    cargo_description TEXT,
    pickup_address VARCHAR(255) NOT NULL,
    dropoff_address VARCHAR(255) NOT NULL,
    base_price DECIMAL(10,2) NOT NULL,
    final_price DECIMAL(10,2) NULL,
    period VARCHAR(20) NULL,
    special_instructions TEXT NULL,
    auction_duration_hours INT(11) NOT NULL DEFAULT 24,
    auction_end_time DATETIME NULL,
    status ENUM('pending', 'bidding', 'assigned', 'at_pickup', 'en_route', 'at_dropoff', 'delivered', 'cancelled') DEFAULT 'pending',
    expected_delivery_date DATETIME NOT NULL,
    actual_delivery_date DATETIME NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    FOREIGN KEY (shipper_id) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS bids (
    id INT(11) NOT NULL AUTO_INCREMENT,
    shipment_id INT(11) NOT NULL,
    driver_id INT(11) NOT NULL,
    bid_amount DECIMAL(10,2) NOT NULL,
    estimated_days INT(11) NOT NULL,
    bid_status ENUM('pending', 'accepted', 'rejected') DEFAULT 'pending',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    FOREIGN KEY (shipment_id) REFERENCES shipments(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

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
    FOREIGN KEY (shipment_id) REFERENCES shipments(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS wallets (
    id INT(11) NOT NULL AUTO_INCREMENT,
    user_id INT(11) NOT NULL,
    current_balance DECIMAL(15,2) DEFAULT 0.00,
    PRIMARY KEY (id),
    FOREIGN KEY (user_id) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS trucks (
    id INT(11) NOT NULL AUTO_INCREMENT,
    user_id INT(11) NOT NULL,
    plate_number VARCHAR(20) NOT NULL,
    isthimara_no TEXT NOT NULL,
    truck_type VARCHAR(100) NOT NULL,
    capacity_kg DECIMAL(10,2) NOT NULL,
    manufacturing_year INT(4) NULL,
    insurance_expiry_date DATE NULL,
    is_active TINYINT(1) NOT NULL DEFAULT 0,
    verification_status ENUM('pending', 'verified', 'rejected') DEFAULT 'pending',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uniq_plate_number (plate_number),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS messages (
    id INT(11) NOT NULL AUTO_INCREMENT,
    shipment_id INT(11) NOT NULL,
    sender_id INT(11) NOT NULL,
    receiver_id INT(11) NOT NULL,
    message TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    KEY idx_messages_shipment_created (shipment_id, created_at),
    FOREIGN KEY (shipment_id) REFERENCES shipments(id) ON DELETE CASCADE,
    FOREIGN KEY (sender_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (receiver_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS compliance_documents (
  document_id int(11) NOT NULL AUTO_INCREMENT,
  user_id int(11) NOT NULL,
  document_type enum('driver_license','vehicle_insurance','commercial_registration','tax_certificate','safety_certificate') COLLATE utf8mb4_unicode_ci NOT NULL,
  document_url varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  issue_date date DEFAULT NULL,
  expiry_date date NOT NULL,
  is_verified tinyint(1) DEFAULT '0',
  verified_by int(11) DEFAULT NULL,
  verified_at timestamp NULL DEFAULT NULL,
  verification_notes text COLLATE utf8mb4_unicode_ci,
  uploaded_at timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  created_at timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (document_id),
  KEY verified_by (verified_by),
  KEY idx_user_id (user_id),
  KEY idx_document_type (document_type),
  KEY idx_expiry_date (expiry_date),
  KEY idx_is_verified (is_verified),
  KEY idx_compliance_status (user_id,expiry_date,is_verified),
  CONSTRAINT compliance_documents_ibfk_1 FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
  CONSTRAINT compliance_documents_ibfk_2 FOREIGN KEY (verified_by) REFERENCES users (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

