const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const pool = require('../config/db');
const User = require('../models/User');
const Wallet = require('../models/Wallet');
const Truck = require('../models/Truck');
const Rating = require('../models/Rating');
const Shipment = require('../models/Shipment');
const ComplianceDocument = require('../models/ComplianceDocument');
const { encryptText, decryptText } = require('../utils/encryption');

const JWT_SECRET = process.env.JWT_SECRET || 'secret_key';

const register = async (req, res) => {
  let connection;
  try {
    const {
      fullName, email, phone, password, role = 'driver',
      licenseNo = null, commercialNo = null, documentPath = null,
      issueDate = null, expiryDate = null,
      truckType = null, plateNumber = null, isthimaraNo = null
    } = req.body;

    const normalizedEmail = (email ?? '').toString().trim().toLowerCase();
    const normalizedPhone = (phone ?? '').toString().trim();

    // Convert empty strings to null for database
    const finalIssueDate = (issueDate && issueDate.trim() !== '') ? issueDate : null;
    const finalExpiryDate = (expiryDate && expiryDate.trim() !== '') ? expiryDate : null;

    console.log('[register] Input:', { fullName, role, finalIssueDate, finalExpiryDate });

    if (!fullName || !normalizedEmail || !normalizedPhone || !password || password.length < 6) {
      return res.status(400).json({ message: 'البيانات الأساسية غير مكتملة' });
    }

    if (role === 'driver' && (!licenseNo || !truckType || !plateNumber || !isthimaraNo)) {
      return res.status(400).json({ message: 'بيانات السائق والشاحنة غير مكتملة' });
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

    if (role === 'driver') {
      const now = new Date();
      await connection.execute(
        'INSERT INTO trucks (user_id, plate_number, isthimara_no, truck_type, capacity_kg, manufacturing_year, insurance_expiry_date, verification_status, is_active) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [userId, plateNumber.trim(), encryptText(isthimaraNo.trim()), truckType.trim(), 0, now.getFullYear(), new Date(now.getFullYear() + 1, now.getMonth(), now.getDate()).toISOString().split('T')[0], 'pending', 1]
      );
    }

    // Insert into compliance_documents table
    if (documentPath) {
      const docType = role === 'driver' ? 'driver_license' : 'commercial_registration';
      const safeExpiryDate = finalExpiryDate || '2099-12-31';

      // التأكد من حفظ المسار (Key) فقط وليس الرابط الكامل
      // إذا كان documentPath يحتوي على http، سنحاول استخراج الـ Key منه
      let storageKey = documentPath;
      if (documentPath.includes('http')) {
        try {
          const urlParts = new URL(documentPath);
          const pathSegments = urlParts.pathname.split('/');
          // تخطي أول جزئين (السلاش واسم الباكت) للحصول على المسار
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

    const token = jwt.sign({ id: userId, role }, JWT_SECRET, { expiresIn: '30d' });
    res.status(201).json({ success: true, user: { id: userId, role }, token });
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

    const token = jwt.sign({ id: user.id, role: user.role }, JWT_SECRET, { expiresIn: '30d' });
    res.json({ success: true, user: { id: user.id, role: user.role, full_name: user.full_name, email: user.email, phone: user.phone }, token });
  } catch (error) {
    res.status(500).json({ message: 'خطأ في تسجيل الدخول' });
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
    const encryptedLicenseNo = licenseNo ? encryptText(licenseNo) : null;
    const encryptedCommercialNo = commercialNo ? encryptText(commercialNo) : null;

    await pool.execute(
      'UPDATE users SET full_name = ?, email = ?, phone = ?, license_no = ?, commercial_no = ? WHERE id = ?',
      [fullName, email, phone, encryptedLicenseNo, encryptedCommercialNo, id]
    );
    res.json({ message: 'تم التحديث بنجاح' });
  } catch (error) {
    res.status(500).json({ message: 'خطأ في التحديث' });
  }
};

const getProfile = async (req, res) => {
  try {
    const { id } = req.params;
    const user = await User.findById(id);
    if (!user) return res.status(404).json({ message: 'غير موجود' });

    const licenseNo = user.license_no ? decryptText(user.license_no) : null;
    const commercialNo = user.commercial_no ? decryptText(user.commercial_no) : null;

    let stats = {};
    if (user.role === 'driver') {
      const tripStats = await Shipment.getDriverStats(id);
      stats = { completed_trips: tripStats.completed_trips, total_earnings: tripStats.total_earnings };
    } else if (user.role === 'shipper') {
      const shipperStats = await Shipment.getShipperStats(id);
      stats = {
        total_shipments: shipperStats.total_shipments,
        delivered_shipments: shipperStats.delivered_shipments,
        active_shipments: shipperStats.active_shipments,
      };
    }

    let ratingBlock = {};
    try {
      const avg = await Rating.getAverageRating(id);
      ratingBlock = {
        average_rating: avg.average_rating != null ? Number(avg.average_rating).toFixed(2) : '0.00',
        ratings_total: avg.total_ratings || 0,
        rating: avg.average_rating != null ? Number(avg.average_rating).toFixed(2) : '0.00',
      };
    } catch (_) {
      ratingBlock = { average_rating: '0.00', ratings_total: 0, rating: '0.00' };
    }

    res.json({
      ...user,
      license_no: licenseNo,
      commercial_no: commercialNo,
      ...stats,
      ...ratingBlock,
    });
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

module.exports = {
  register,
  login,
  getPendingUsers,
  setUserVerification,
  updateProfile,
  getProfile,
  updateDeviceToken,
};
