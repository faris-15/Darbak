/**
 * Optional Firebase Cloud Messaging (FCM) using firebase-admin.
 * Set FIREBASE_SERVICE_ACCOUNT_PATH to a JSON service account file, or leave unset to skip push.
 */
let adminApp;

const tryInit = () => {
  if (adminApp !== undefined) return adminApp;
  adminApp = null;
  try {
    const path = process.env.FIREBASE_SERVICE_ACCOUNT_PATH;
    if (!path) return null;
    const admin = require('firebase-admin');
    const serviceAccount = require(path);
    if (!admin.apps.length) {
      admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
    }
    adminApp = admin;
    return adminApp;
  } catch (e) {
    console.warn('[fcmPush] FCM disabled:', e.message);
    adminApp = null;
    return null;
  }
};

const sendPushToUser = async (userId, { title, body, data = {} }) => {
  const admin = tryInit();
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
