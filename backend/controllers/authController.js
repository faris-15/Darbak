/**
 * مصادقة المستخدمين: تسجيل، دخول بكلمة مرور MySQL، ودخول/مزامنة عبر Firebase Auth.
 * تمت إزالة مسارات إعادة تعيين كلمة المرور عبر SMTP/الرموز المخزّنة محلياً؛ الاستعادة عبر POST /auth/password-reset-request ثم بريد Firebase.
 * بعد التسجيل في MySQL يُنشأ (إن أمكن) مستخدم بنفس البريف وكلمة المرور في Firebase عبر Admin SDK؛ طلب إعادة التعيين يمر عبر POST /auth/password-reset-request (sendOobCode).
 */
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const pool = require('../config/db');
const User = require('../models/User');
const Truck = require('../models/Truck');
const { encryptText, decryptText } = require('../utils/encryption');
const { buildProfileResponse, resolveProfileImage } = require('../services/profileService');
const { emitAdminDashboard } = require('../utils/adminRealtime');
const { getFirebaseAdminApp } = require('../utils/firebaseAdminApp');
const { validateTruckClassification } = require('../utils/truckClassificationValidator');
const { ensureTruckClassificationSchema } = require('../utils/truckClassificationSchema');

const JWT_SECRET = process.env.JWT_SECRET || 'secret_key';

/**
 * ينشئ مستخدم Email/Password في Firebase (نفس بريد التسجيل وكلمة المرور) حتى تعمل إعادة التعيين من التطبيق.
 * لا يُفشل مسار التسجيم في MySQL إذا تعذّر Firebase؛ يُسجّل تحذير فقط.
 */
async function ensureFirebaseAuthUserForRegistration(email, plainPassword) {
  const adminApp = getFirebaseAdminApp();
  if (!adminApp) {
    console.warn(
      '[register] Firebase Admin غير جاهز (تأكد من FIREBASE_SERVICE_ACCOUNT_PATH ووجود ملف JSON). تخطي إنشاء مستخدم Firebase',
    );
    return;
  }
  try {
    await adminApp.auth().createUser({
      email,
      password: plainPassword,
      emailVerified: false,
    });
    console.log('[register] Firebase Auth: تم إنشاء المستخدم', email);
  } catch (e) {
    if (e.code === 'auth/email-already-exists') {
      console.log('[register] Firebase Auth: البريد مسجل مسبقاً في Firebase — لا حاجة لإنشاء', email);
      return;
    }
    console.warn('[register] Firebase Auth createUser فشل:', e.code || '', e.message);
  }
}

const register = async (req, res) => {
  let connection;
  try {
    const {
      fullName, email, phone, password, role = 'driver',
      licenseNo = null, commercialNo = null, documentPath = null,
      issueDate = null, expiryDate = null,
      truckType = null, plateNumber = null, isthimaraNo = null,
      category = null, axle_count = null, body_type = null,
      payload_capacity = null, max_weight_tons = null,
    } = req.body;

    const normalizedEmail = (email ?? '').toString().trim().toLowerCase();
    const normalizedPhone = (phone ?? '').toString().trim();

    const finalIssueDate = (issueDate && issueDate.trim() !== '') ? issueDate : null;
    const finalExpiryDate = (expiryDate && expiryDate.trim() !== '') ? expiryDate : null;

    console.log('[register] Input:', { fullName, role, finalIssueDate, finalExpiryDate });

    if (!fullName || !normalizedEmail || !normalizedPhone || !password || password.length < 6) {
      return res.status(400).json({ message: 'البيانات الأساسية غير مكتملة' });
    }

    let driverTruckClassification = null;
    if (role === 'driver') {
      if (!licenseNo || !plateNumber || !isthimaraNo) {
        return res.status(400).json({ message: 'بيانات السائق والشاحنة غير مكتملة' });
      }
      const classificationResult = validateTruckClassification(req.body, { requireAll: true });
      if (!classificationResult.ok) {
        return res.status(400).json({
          message: classificationResult.errors[0] || 'تصنيف الشاحنة غير صالح',
          errors: classificationResult.errors,
        });
      }
      driverTruckClassification = classificationResult.data;
    }

    const [phoneUsed, emailUsed] = await Promise.all([
      User.existsByPhone(normalizedPhone),
      User.existsByEmail(normalizedEmail),
    ]);
    if (phoneUsed || emailUsed) {
      return res.status(400).json({ message: 'رقم الجوال أو البريد مستخدم مسبقاً' });
    }

    const hashed = await bcrypt.hash(password, 10);
    const encryptedLicenseNo = licenseNo ? encryptText(licenseNo) : null;
    const encryptedCommercialNo = commercialNo ? encryptText(commercialNo) : null;

    connection = await pool.getConnection();
    await connection.beginTransaction();

    const [userInsert] = await connection.execute(
      'INSERT INTO users (full_name, email, phone, password, role, license_no, commercial_no, document_path, issue_date, expiry_date) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [fullName, normalizedEmail, normalizedPhone, hashed, role, encryptedLicenseNo, encryptedCommercialNo, documentPath, finalIssueDate, finalExpiryDate || '2099-12-31']
    );
    const userId = userInsert.insertId;

    await connection.execute('INSERT INTO wallets (user_id, current_balance) VALUES (?, ?)', [userId, 0]);

    if (role === 'driver' && driverTruckClassification) {
      await ensureTruckClassificationSchema();
      const now = new Date();
      const c = driverTruckClassification;
      await connection.execute(
        `INSERT INTO trucks (
           user_id, plate_number, isthimara_no, truck_type,
           category, axle_count, body_type, payload_capacity, max_weight_tons,
           capacity_kg, manufacturing_year, insurance_expiry_date, verification_status, is_active
         ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
        [
          userId,
          plateNumber.trim(),
          encryptText(isthimaraNo.trim()),
          c.truck_type,
          c.category,
          c.axle_count,
          c.body_type,
          c.payload_capacity,
          c.max_weight_tons,
          c.capacity_kg,
          now.getFullYear(),
          new Date(now.getFullYear() + 1, now.getMonth(), now.getDate()).toISOString().split('T')[0],
          'pending',
          1,
        ]
      );
    }

    if (documentPath) {
      const docType = role === 'driver' ? 'driver_license' : 'commercial_registration';
      const safeExpiryDate = finalExpiryDate || '2099-12-31';

      let storageKey = documentPath;
      if (documentPath.includes('http')) {
        try {
          const urlParts = new URL(documentPath);
          const pathSegments = urlParts.pathname.split('/');
          storageKey = pathSegments.slice(2).join('/');
        } catch (e) {
          console.error("Error parsing document URL, saving as is:", e);
        }
      }

      await connection.execute(
        'INSERT INTO compliance_documents (user_id, document_type, document_url, issue_date, expiry_date) VALUES (?, ?, ?, ?, ?)',
        [userId, docType, storageKey, finalIssueDate, safeExpiryDate]
      );
    }

    await connection.commit();

    await ensureFirebaseAuthUserForRegistration(normalizedEmail, password);

    emitAdminDashboard(req, 'user.registered', { userId, role });
    const token = jwt.sign({ id: userId, role }, JWT_SECRET, { expiresIn: '30d' });
    res.status(201).json({
      success: true,
      user: { id: userId, role, verification_status: 'pending' },
      token,
    });
  } catch (error) {
    if (connection) await connection.rollback();
    console.error('[register] Error:', error);
    res.status(500).json({ message: 'حدث خطأ في السيرفر أثناء التسجيل: ' + error.message });
  } finally {
    if (connection) connection.release();
  }
};

const login = async (req, res) => {
  try {
    const { identifier, password } = req.body;
    if (!identifier || !password) return res.status(400).json({ message: 'البيانات مطلوبة' });

    const user = await User.findByPhoneOrEmail(identifier);
    if (!user || !(await bcrypt.compare(password, user.password))) {
      return res.status(401).json({ message: 'بيانات الدخول غير صحيحة' });
    }

    if (user.is_active === 0 || user.is_active === false) {
      return res.status(403).json({ message: 'تم تعطيل هذا الحساب. تواصل مع الدعم.' });
    }

    const profileImageUrl = user.profile_image_url ? await resolveProfileImage(user.profile_image_url) : null;
    const token = jwt.sign({ id: user.id, role: user.role }, JWT_SECRET, { expiresIn: '30d' });
    res.json({
      success: true,
      user: {
        id: user.id,
        role: user.role,
        full_name: user.full_name,
        email: user.email,
        phone: user.phone,
        verification_status: user.verification_status || 'pending',
        profile_image_url: profileImageUrl,
        profileImageUrl,
        profileImageKey: user.profile_image_url || null,
      },
      token,
    });
  } catch (error) {
    res.status(500).json({ message: 'خطأ في تسجيل الدخول' });
  }
};

/**
 * تسجيل دخول التطبيق بعد نجاح FirebaseAuth (مثلاً بعد إعادة تعيين كلمة المرور في Firebase).
 * يتحقق من idToken عبر firebase-admin، يطابق البريد مع جدول users، ويُصدِر نفس JWT الحالي.
 * إذا وُجدت كلمة مرور في الطلب تُحدَّث في MySQL (مزامنة مع كلمة مرور Firebase بعد إعادة التعيين).
 */
const loginWithFirebase = async (req, res) => {
  try {
    const idToken = (req.body.idToken || '').toString().trim();
    const password = (req.body.password || '').toString();

    if (!idToken) {
      return res.status(400).json({ message: 'رمز المصادقة مطلوب' });
    }

    const admin = getFirebaseAdminApp();
    if (!admin) {
      return res.status(503).json({
        message: 'خدمة تسجيل الدخول غير متاحة مؤقتاً. حاول لاحقاً.',
      });
    }

    const decoded = await admin.auth().verifyIdToken(idToken);
    const email = (decoded.email || '').toString().trim().toLowerCase();
    if (!email) {
      return res.status(400).json({
        message: 'تعذّر التحقق من الحساب. استخدم بريداً إلكترونياً مسجّلاً.',
      });
    }

    const user = await User.findByEmail(email);
    if (!user) {
      return res.status(404).json({
        message: 'لا يوجد حساب مسجّل بهذا البريد. أنشئ الحساب من التطبيق أولاً.',
      });
    }

    if (user.is_active === 0 || user.is_active === false) {
      return res.status(403).json({ message: 'تم تعطيل هذا الحساب. تواصل مع الدعم.' });
    }

    if (password) {
      if (
        password.length < 8 ||
        password.length > 128 ||
        !/\p{L}/u.test(password) ||
        !/[0-9]/.test(password)
      ) {
        return res.status(400).json({
          message: 'كلمة المرور يجب أن تكون 8 أحرف على الأقل وتحتوي على حرف ورقم',
        });
      }
      const hashedPassword = await bcrypt.hash(password, 12);
      await pool.execute('UPDATE users SET password = ? WHERE id = ?', [hashedPassword, user.id]);
    }

    const profileImageUrl = user.profile_image_url ? await resolveProfileImage(user.profile_image_url) : null;
    const token = jwt.sign({ id: user.id, role: user.role }, JWT_SECRET, { expiresIn: '30d' });
    res.json({
      success: true,
      user: {
        id: user.id,
        role: user.role,
        full_name: user.full_name,
        email: user.email,
        phone: user.phone,
        verification_status: user.verification_status || 'pending',
        profile_image_url: profileImageUrl,
        profileImageUrl,
        profileImageKey: user.profile_image_url || null,
      },
      token,
    });
  } catch (error) {
    console.error('[loginWithFirebase]', error.code || '', error.message);
    if (error.code === 'auth/id-token-expired') {
      return res.status(401).json({ message: 'انتهت صلاحية الجلسة. أعد المحاولة.' });
    }
    if (error.code === 'auth/argument-error' || error.code === 'auth/invalid-id-token') {
      return res.status(401).json({ message: 'رمز الدخول غير صالح' });
    }
    return res.status(500).json({ message: 'تعذّر تسجيل الدخول' });
  }
};

const getPendingUsers = async (req, res) => {
  try {
    const users = await User.getPendingVerifications();
    res.json({ success: true, data: users });
  } catch (error) {
    res.status(500).json({ success: false, message: 'خطأ في جلب البيانات' });
  }
};

const setUserVerification = async (req, res) => {
  try {
    const { id } = req.params;
    const { status } = req.body;
    await User.updateVerificationStatus(id, status);
    res.json({ success: true, message: 'تم التحديث' });
  } catch (error) {
    res.status(500).json({ success: false, message: 'خطأ في التحديث' });
  }
};

const updateProfile = async (req, res) => {
  try {
    const { id } = req.params;
    const { fullName, email, phone, licenseNo, commercialNo } = req.body;
    if (req.user && Number(req.user.id) !== Number(id) && req.user.role !== 'admin') {
      return res.status(403).json({ message: 'غير مصرح بتعديل هذا الحساب' });
    }
    const encryptedLicenseNo = licenseNo ? encryptText(licenseNo) : null;
    const encryptedCommercialNo = commercialNo ? encryptText(commercialNo) : null;

    await User.updateProfileFields(id, {
      fullName,
      email,
      phone,
      licenseNo: encryptedLicenseNo,
      commercialNo: encryptedCommercialNo,
    });
    res.json({ message: 'تم التحديث بنجاح' });
  } catch (error) {
    res.status(500).json({ message: 'خطأ في التحديث' });
  }
};

const getProfile = async (req, res) => {
  try {
    const { id } = req.params;
    const profile = await buildProfileResponse(id);
    if (!profile) return res.status(404).json({ message: 'غير موجود' });
    res.json(profile);
  } catch (error) {
    res.status(500).json({ message: 'خطأ في جلب البيانات' });
  }
};

const updateDeviceToken = async (req, res) => {
  try {
    const uid = req.user?.id;
    const { token } = req.body;
    if (!uid) return res.status(401).json({ message: 'غير مصرح' });
    if (!token || typeof token !== 'string') {
      return res.status(400).json({ message: 'رمز الجهاز مطلوب' });
    }
    await pool.execute('UPDATE users SET fcm_token = ? WHERE id = ?', [token, uid]);
    return res.json({ success: true });
  } catch (error) {
    console.warn('[updateDeviceToken]', error.message);
    return res.status(500).json({ message: 'تعذر حفظ رمز الإشعارات (تأكد من تشغيل migration لعمود fcm_token)' });
  }
};

/** حد أقصى بسيط لطلبات إعادة التعيين لكل IP (ساعة) لمنع الإساءة */
const passwordResetIpHits = new Map();
const PASSWORD_RESET_WINDOW_MS = 60 * 60 * 1000;
const PASSWORD_RESET_MAX_PER_IP = 25;

function allowPasswordResetFromIp(ip) {
  const now = Date.now();
  const key = String(ip || 'unknown');
  let arr = passwordResetIpHits.get(key) || [];
  arr = arr.filter((t) => now - t < PASSWORD_RESET_WINDOW_MS);
  if (arr.length >= PASSWORD_RESET_MAX_PER_IP) return false;
  arr.push(now);
  passwordResetIpHits.set(key, arr);
  return true;
}

/**
 * طلب إعادة تعيين كلمة المرور عبر Firebase:
 * 1) التحقق من وجود المستخدم في Firebase Auth (Admin).
 * 2) استدعاء REST الرسمي accounts:sendOobCode (نفس مسار الـ SDK) مع تسجيل الرد في السجل لتسهيل التشخيص.
 */
const requestFirebasePasswordReset = async (req, res) => {
  try {
    const emailRaw = (req.body?.email ?? '').toString().trim().toLowerCase();
    if (!emailRaw || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(emailRaw)) {
      return res.status(400).json({ success: false, message: 'البريد غير صالح' });
    }
    if (!allowPasswordResetFromIp(req.ip)) {
      return res.status(429).json({ success: false, message: 'طلبات كثيرة، حاول لاحقاً' });
    }

    const adminApp = getFirebaseAdminApp();
    if (!adminApp) {
      return res.status(503).json({
        success: false,
        message: 'خدمة إعادة تعيين كلمة المرور غير متاحة مؤقتاً.',
      });
    }

    try {
      await adminApp.auth().getUserByEmail(emailRaw);
    } catch (e) {
      if (e.code === 'auth/user-not-found') {
        return res.status(404).json({ success: false, message: 'لا يوجد حساب بهذا البريد.' });
      }
      throw e;
    }

    const apiKey = process.env.FIREBASE_WEB_API_KEY;
    if (!apiKey || !String(apiKey).trim()) {
      return res.status(503).json({
        success: false,
        message: 'خدمة إعادة تعيين كلمة المرور غير متاحة مؤقتاً.',
      });
    }

    const url = `https://identitytoolkit.googleapis.com/v1/accounts:sendOobCode?key=${encodeURIComponent(apiKey.trim())}`;
    const r = await fetch(url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Accept-Language': 'ar',
      },
      body: JSON.stringify({
        requestType: 'PASSWORD_RESET',
        email: emailRaw,
      }),
    });
    const data = await r.json().catch(() => ({}));
    if (!r.ok) {
      const errMsg = (data.error && data.error.message) ? String(data.error.message) : '';
      console.warn('[password-reset-request] sendOobCode failed', r.status, errMsg, JSON.stringify(data).slice(0, 500));
      if (errMsg.includes('EMAIL_NOT_FOUND') || errMsg.includes('USER_NOT_FOUND')) {
        return res.status(404).json({ success: false, message: 'لا يوجد حساب بهذا البريد.' });
      }
      return res.status(502).json({
        success: false,
        message: 'تعذّر إرسال رابط إعادة التعيين حالياً. حاول لاحقاً.',
      });
    }

    console.log('[password-reset-request] sendOobCode OK', emailRaw);
    return res.json({ success: true, message: 'تم الطلب.' });
  } catch (e) {
    console.error('[password-reset-request]', e);
    return res.status(500).json({ success: false, message: 'خطأ في الخادم' });
  }
};

module.exports = {
  register,
  login,
  loginWithFirebase,
  requestFirebasePasswordReset,
  getPendingUsers,
  setUserVerification,
  updateProfile,
  getProfile,
  updateDeviceToken,
};
