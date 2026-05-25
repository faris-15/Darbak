const bcrypt = require('bcryptjs');
const pool = require('../config/db');

async function fixAdmin() {
  try {
    const phone = '1111';
    const password = 'password123'; // يمكنك تغييرها
    const hashed = await bcrypt.hash(password, 10);

    const [rows] = await pool.execute('SELECT id FROM users WHERE phone = ?', [phone]);

    if (rows.length > 0) {
      console.log('Updating existing admin user...');
      await pool.execute(
        'UPDATE users SET password = ?, role = "admin", is_active = 1 WHERE phone = ?',
        [hashed, phone]
      );
      console.log('Admin user updated successfully.');
    } else {
      console.log('Creating new admin user...');
      await pool.execute(
        'INSERT INTO users (full_name, email, phone, password, role, is_active) VALUES (?, ?, ?, ?, ?, ?)',
        ['System Admin', 'admin@darbak.app', phone, hashed, 'admin', 1]
      );
      console.log('Admin user created successfully.');
    }
  } catch (error) {
    console.error('Error fixing admin:', error);
  } finally {
    process.exit();
  }
}

fixAdmin();
