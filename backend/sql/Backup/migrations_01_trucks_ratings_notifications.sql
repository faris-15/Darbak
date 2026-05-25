-- Darbak Migrations: Trucks, Ratings, Notifications, BiddingRooms

-- 1. Trucks table (Vehicle Management for Drivers)
CREATE TABLE IF NOT EXISTS trucks (
    id INT(11) NOT NULL AUTO_INCREMENT,
    driver_id INT(11) NOT NULL UNIQUE,
    plate_no VARCHAR(50) NOT NULL UNIQUE,
    truck_type VARCHAR(100) NOT NULL,
    capacity_tons DECIMAL(10,2) NOT NULL,
    year_manufactured INT(4),
    insurance_expiry_date DATE,
    vehicle_photo_path VARCHAR(255),
    verification_status ENUM('pending', 'verified', 'rejected') DEFAULT 'pending',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    FOREIGN KEY (driver_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 2. Ratings table (Bilateral Ratings System)
CREATE TABLE IF NOT EXISTS ratings (
    id INT(11) NOT NULL AUTO_INCREMENT,
    shipment_id INT(11) NOT NULL,
    rater_id INT(11) NOT NULL,
    ratee_id INT(11) NOT NULL,
    rating_stars INT(1) NOT NULL CHECK (rating_stars >= 1 AND rating_stars <= 5),
    comments TEXT,
    rater_role ENUM('driver', 'shipper') NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY unique_rating_per_shipment (shipment_id, rater_id),
    FOREIGN KEY (shipment_id) REFERENCES shipments(id) ON DELETE CASCADE,
    FOREIGN KEY (rater_id) REFERENCES users(id),
    FOREIGN KEY (ratee_id) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 3. Notifications table
CREATE TABLE IF NOT EXISTS notifications (
    id INT(11) NOT NULL AUTO_INCREMENT,
    user_id INT(11) NOT NULL,
    notification_type ENUM('new_bid', 'bid_accepted', 'bid_rejected', 'shipment_assigned', 'delivery_completed', 'rating_received', 'generic') DEFAULT 'generic',
    title VARCHAR(255),
    message TEXT NOT NULL,
    related_shipment_id INT(11),
    related_bid_id INT(11),
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (related_shipment_id) REFERENCES shipments(id) ON DELETE CASCADE,
    FOREIGN KEY (related_bid_id) REFERENCES bids(id) ON DELETE CASCADE,
    INDEX idx_user_created (user_id, created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 4. Bidding Rooms (Room-based exclusive bidding)
CREATE TABLE IF NOT EXISTS bidding_rooms (
    id INT(11) NOT NULL AUTO_INCREMENT,
    shipment_id INT(11) NOT NULL UNIQUE,
    active_driver_id INT(11),
    lowest_bidder_id INT(11),
    lowest_bid_amount DECIMAL(10,2),
    room_status ENUM('open', 'locked', 'closed') DEFAULT 'open',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    FOREIGN KEY (shipment_id) REFERENCES shipments(id) ON DELETE CASCADE,
    FOREIGN KEY (active_driver_id) REFERENCES users(id),
    FOREIGN KEY (lowest_bidder_id) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 5. ePOD (Electronic Proof of Delivery)
CREATE TABLE IF NOT EXISTS epod (
    id INT(11) NOT NULL AUTO_INCREMENT,
    shipment_id INT(11) NOT NULL UNIQUE,
    driver_id INT(11) NOT NULL,
    photo_path VARCHAR(500) NOT NULL,
    signature_path VARCHAR(500),
    recipient_name VARCHAR(150),
    delivery_notes TEXT,
    captured_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    FOREIGN KEY (shipment_id) REFERENCES shipments(id) ON DELETE CASCADE,
    FOREIGN KEY (driver_id) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Add new columns to shipments if they don't exist
ALTER TABLE shipments ADD COLUMN IF NOT EXISTS pod_photo_path VARCHAR(500) NULL;
ALTER TABLE shipments ADD COLUMN IF NOT EXISTS pod_signature_path VARCHAR(500) NULL;
ALTER TABLE shipments ADD COLUMN IF NOT EXISTS auction_end_time DATETIME NULL;
