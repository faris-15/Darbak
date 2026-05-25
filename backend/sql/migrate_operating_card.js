const pool = require('../config/db');

async function run() {
  try {
    await pool.execute(`
      CREATE TABLE IF NOT EXISTS driver_operating_cards (
        id INT AUTO_INCREMENT PRIMARY KEY,
        driver_id INT NOT NULL,
        file_url VARCHAR(255) NOT NULL,
        file_key VARCHAR(255) NOT NULL,
        file_type VARCHAR(50) NOT NULL,
        expiry_date DATE NOT NULL,
        verification_status ENUM('pending', 'verified', 'rejected', 'expired') DEFAULT 'pending',
        rejection_reason TEXT NULL,
        verified_at TIMESTAMP NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        FOREIGN KEY (driver_id) REFERENCES users(id) ON DELETE CASCADE
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    `);
    console.log('Table driver_operating_cards created successfully');
    process.exit(0);
  } catch (err) {
    console.error('Migration failed:', err);
    process.exit(1);
  }
}

run();
