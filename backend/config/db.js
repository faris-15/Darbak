const mysql = require('mysql2/promise');
const path = require('path');

require('dotenv').config({ path: path.join(__dirname, '..', '.env') });

const pool = mysql.createPool({
  host: process.env.DB_HOST || process.env.MYSQL_HOST || 'localhost',
  user: process.env.MYSQL_USER || 'root',
  password: process.env.MYSQL_PASSWORD || '',
  database: process.env.MYSQL_DATABASE || 'darbak_db',
  port: process.env.MYSQL_PORT || 3306,
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0,
});

// Test the connection
pool.getConnection()
  .then(connection => {
    console.log('تم الاتصال بـ XAMPP MySQL بنجاح');
    connection.release();
  })
  .catch(err => {
    console.error('فشل في الاتصال بقاعدة البيانات:', err.message);
  });

module.exports = pool;
