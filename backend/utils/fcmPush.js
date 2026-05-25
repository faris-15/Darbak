/**
 * Optional Firebase Cloud Messaging (FCM) using firebase-admin.
 * يستخدم نفس تهيئة FIREBASE_SERVICE_ACCOUNT_PATH مثل مصادقة تسجيل الدخول عبر Firebase.
 */
const { getFirebaseAdminApp } = require('./firebaseAdminApp');

const sendPushToUser = async (userId, { title, body, data = {} }) => {
  const admin = getFirebaseAdminApp();
  if (!admin) return { sent: false, reason: 'no_admin' };

  let token = null;
  try {
    const pool = require('../config/db');
    const [rows] = await pool.execute('SELECT fcm_token FROM users WHERE id = ? LIMIT 1', [userId]);
    token = rows[0]?.fcm_token || null;
  } catch (e) {
    console.warn('[fcmPush] Could not read fcm_token:', e.message);
    return { sent: false, reason: 'db' };
  }
  if (!token) return { sent: false, reason: 'no_token' };

  try {
    await admin.messaging().send({
      token,
      notification: { title, body },
      data,
    });
    return { sent: true };
  } catch (e) {
    console.warn('[fcmPush] send failed:', e.message);
    return { sent: false, reason: e.message };
  }
};

module.exports = { sendPushToUser };
