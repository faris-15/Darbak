/**
 * Admin bootstrap script.
 *
 * Creates (or updates) a single administrator user using credentials supplied
 * via environment variables. Run once on a fresh database, then change the
 * password from the admin portal.
 *
 * USAGE:
 *   $env:ADMIN_PHONE="0500000000"; $env:ADMIN_PASSWORD="aStrongPassword"; node backend/utils/fix_admin.js   # PowerShell
 *   ADMIN_PHONE=0500000000 ADMIN_PASSWORD=aStrongPassword node backend/utils/fix_admin.js                    # bash
 *
 * Optional:
 *   ADMIN_EMAIL     (default: admin@darbak.app)
 *   ADMIN_FULL_NAME (default: System Admin)
 *
 * This script intentionally contains NO hardcoded credentials so it is safe to
 * commit and ship. It will exit with a non-zero status if mandatory variables
 * are missing.
 */
'use strict';

const bcrypt = require('bcryptjs');
const pool = require('../config/db');

async function fixAdmin() {
  const phone = process.env.ADMIN_PHONE;
  const password = process.env.ADMIN_PASSWORD;
  const email = process.env.ADMIN_EMAIL || 'admin@darbak.app';
  const fullName = process.env.ADMIN_FULL_NAME || 'System Admin';

  if (!phone || !password) {
    console.error(
      'ERROR: ADMIN_PHONE and ADMIN_PASSWORD environment variables are required.\n' +
        'Example (PowerShell):\n' +
        '  $env:ADMIN_PHONE="0500000000"; $env:ADMIN_PASSWORD="StrongPass!1"; node backend/utils/fix_admin.js'
    );
    process.exit(1);
  }

  if (String(password).length < 8) {
    console.error('ERROR: ADMIN_PASSWORD must be at least 8 characters.');
    process.exit(1);
  }

  try {
    const hashed = await bcrypt.hash(String(password), 10);
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
        [fullName, email, phone, hashed, 'admin', 1]
      );
      console.log('Admin user created successfully.');
    }
  } catch (error) {
    console.error('Error fixing admin:', error.message);
    process.exitCode = 1;
  } finally {
    process.exit();
  }
}

fixAdmin();
