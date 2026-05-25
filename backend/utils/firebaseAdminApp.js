/**
 * تهيئة موحّدة لـ firebase-admin (مصادقة الرموز + FCM).
 * يعتمد على FIREBASE_SERVICE_ACCOUNT_PATH (مسار ملف JSON لحساب الخدمة).
 * لا يُعاد تهيئة التطبيق إن وُجد تطبيق Firebase افتراضي مسبقاً.
 */
const path = require('path');
const admin = require('firebase-admin');

let cached;

const getFirebaseAdminApp = () => {
  if (cached !== undefined) return cached;
  cached = null;
  try {
    const envPath = process.env.FIREBASE_SERVICE_ACCOUNT_PATH;
    if (!envPath) return null;
    const resolved = path.isAbsolute(envPath)
      ? envPath
      : path.join(process.cwd(), envPath);
    // eslint-disable-next-line import/no-dynamic-require, global-require
    const serviceAccount = require(resolved);
    if (!admin.apps.length) {
      admin.initializeApp({
        credential: admin.credential.cert(serviceAccount),
      });
    }
    cached = admin;
    return cached;
  } catch (e) {
    const envPath = process.env.FIREBASE_SERVICE_ACCOUNT_PATH;
    const resolved = envPath && path.isAbsolute(envPath)
      ? envPath
      : envPath
        ? path.join(process.cwd(), envPath)
        : '(غير مضبوط)';
    console.warn('[firebaseAdminApp] init failed:', e.message, '| path:', resolved);
    cached = null;
    return null;
  }
};

module.exports = { getFirebaseAdminApp };
