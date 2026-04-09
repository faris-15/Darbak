-- Darbak MySQL schema

CREATE DATABASE IF NOT EXISTS darbak_db;
USE darbak_db;

CREATE TABLE IF NOT EXISTS users (
    id INT(11) NOT NULL AUTO_INCREMENT,
    full_name VARCHAR(150) NOT NULL,
    phone VARCHAR(15) NOT NULL UNIQUE,
    password VARCHAR(255) NOT NULL,
    role ENUM('driver', 'shipper', 'admin') NOT NULL DEFAULT 'driver',
    license_no VARCHAR(50) NULL,
    commercial_no VARCHAR(50) NULL,
    document_path VARCHAR(255) NULL,
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
    status ENUM('pending', 'bidding', 'assigned', 'on_way', 'delivered', 'cancelled') DEFAULT 'pending',
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

CREATE TABLE IF NOT EXISTS wallets (
    id INT(11) NOT NULL AUTO_INCREMENT,
    user_id INT(11) NOT NULL,
    current_balance DECIMAL(15,2) DEFAULT 0.00,
    PRIMARY KEY (id),
    FOREIGN KEY (user_id) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

