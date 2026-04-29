const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const pool = require('../config/db');
const User = require('../models/User');
const Wallet = require('../models/Wallet');
const Truck = require('../models/Truck');
const { encryptText, decryptText } = require('../utils/encryption');

const JWT_SECRET = process.env.JWT_SECRET || 'secret_key';

const register = async (req, res) => {
  let connection;
  try {
    const { fullName, email, phone, password, role = 'driver', licenseNo = null, commercialNo = null, documentPath = null, issueDate = null, expiryDate = null, truckType = null, plateNumber = null, isthimaraNo = null } = req.body;
    const normalizedEmail = (email ?? '').toString().trim().toLowerCase();
    const normalizedPhone = (phone ?? '').toString().trim();

    console.log('[register] Input:', { fullName, email: normalizedEmail, phone: normalizedPhone, role, issueDate, expiryDate });

    // Validate required fields
    if (!fullName || fullName.trim() === '') {
      return res.status(400).json({ message: 'الاسم الكامل مطلوب' });
    }
    if (!normalizedEmail) {
      return res.status(400).json({ message: 'البريد الإلكتروني مطلوب' });
    }
    if (!normalizedPhone) {
      return res.status(400).json({ message: 'رقم الجوال مطلوب' });
    }
    if (!password || password.length < 6) {
      return res.status(400).json({ message: 'كلمة المرور يجب أن تكون 6 أحرف على الأقل' });
    }
    if (!['driver', 'shipper', 'admin'].includes(role)) {
      return res.status(400).json({ message: 'الدور غير صحيح' });
    }

    // Check for role-specific requirements
    if (role === 'driver' && (!licenseNo || licenseNo.trim() === '')) {
      return res.status(400).json({ message: 'رقم الرخصة مطلوب للسائقين' });
    }
    if (role === 'driver' && (!truckType || !plateNumber || !isthimaraNo)) {
      return res.status(400).json({ message: 'بيانات الشاحنة الأساسية مطلوبة للسائقين' });
    }
    if (role === 'shipper' && (!commercialNo || commercialNo.trim() === '')) {
      return res.status(400).json({ message: 'رقم السجل التجاري مطلوب للشاحنين' });
    }

    const [phoneUsed, emailUsed] = await Promise.all([
      User.existsByPhone(normalizedPhone),
      User.existsByEmail(normalizedEmail),
    ]);
    if (phoneUsed) {
      return res.status(400).json({ message: 'رقم الجوال مستخدم بالفعل' });
    }
    if (emailUsed) {
      return res.status(400).json({ message: 'البريد الإلكتروني مستخدم بالفعل' });
    }

    const hashed = await bcrypt.hash(password, 10);
    const encryptedLicenseNo = licenseNo ? (() => {
      try {
        return encryptText(licenseNo);
      } catch (error) {
        console.error('[register] Encryption failed for licenseNo:', error.message);
        throw error;
      }
    })() : null;
    const encryptedCommercialNo = commercialNo ? (() => {
      try {
        return encryptText(commercialNo);
      } catch (error) {
        console.error('[register] Encryption failed for commercialNo:', error.message);
        throw error;
      }
    })() : null;
    connection = await pool.getConnection();
    await connection.beginTransaction();

    const [userInsert] = await connection.execute(
      'INSERT INTO users (full_name, email, phone, password, role, license_no, commercial_no, document_path, issue_date, expiry_date) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [
        fullName,
        normalizedEmail,
        normalizedPhone,
        hashed,
        role,
        encryptedLicenseNo,
        encryptedCommercialNo,
        documentPath,
        issueDate,
        expiryDate,
      ]
    );
    const userId = userInsert.insertId;

    await connection.execute(
      'INSERT INTO wallets (user_id, current_balance) VALUES (?, ?)',
      [userId, 0]
    );
    if (role === 'driver') {
      const existingPlate = await Truck.findByPlateNumber(plateNumber.trim());
      if (existingPlate) {
        return res.status(400).json({ message: 'رقم اللوحة مستخدم مسبقاً' });
      }
      const now = new Date();
      const defaultManufacturingYear = now.getFullYear();
      const defaultInsuranceExpiryDate = new Date(
        now.getFullYear() + 1,
        now.getMonth(),
        now.getDate()
      )
        .toISOString()
        .split('T')[0];
      await connection.execute(
        'INSERT INTO trucks (user_id, plate_number, isthimara_no, truck_type, capacity_kg, manufacturing_year, insurance_expiry_date, verification_status, is_active) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [
          userId,
          plateNumber.trim(),
          encryptText(isthimaraNo.trim()),
          truckType.trim(),
          0,
          defaultManufacturingYear,
          defaultInsuranceExpiryDate,
          'pending',
          1,
        ]
      );
    }

    await connection.commit();

    const token = jwt.sign({ id: userId, role }, JWT_SECRET, { expiresIn: '30d' });
    console.log('[register] Success:', { userId, role });
    res.status(201).json({
      user: {
        id: userId,
        full_name: fullName,
        email: normalizedEmail,
        phone: normalizedPhone,
        role,
        verification_status: 'pending',
        license_no: licenseNo,
        commercial_no: commercialNo,
        document_path: documentPath,
        issue_date: issueDate,
        expiry_date: expiryDate,
      },
      token,
    });
  } catch (error) {
    if (connection) {
      try {
        await connection.rollback();
      } catch (_) {}
    }
    console.error('[register] Database error:', error.message, 'Code:', error.code, 'SQLState:', error.sqlState);
    res.status(500).json({ message: error.message || 'خطأ في الخادم أثناء التسجيل' });
  } finally {
    if (connection) {
      connection.release();
    }
  }
};

const login = async (req, res) => {
  try {
    const { identifier, password } = req.body;

    console.log('[login] Attempt:', { identifier });

    if (!identifier || !password) {
      return res.status(400).json({ message: 'رقم الجوال/البريد الإلكتروني وكلمة المرور مطلوبان' });
    }

    const user = await User.findByPhoneOrEmail(identifier);
    if (!user) {
      return res.status(401).json({ message: 'بيانات الدخول غير صحيحة' });
    }

    const match = await bcrypt.compare(password, user.password);
    if (!match) {
      return res.status(401).json({ message: 'بيانات الدخول غير صحيحة' });
    }

    const token = jwt.sign({ id: user.id, role: user.role }, JWT_SECRET, { expiresIn: '30d' });
    console.log('[login] Success:', { userId: user.id, role: user.role });
    res.json({
      user: {
        id: user.id,
        name: user.full_name,
        full_name: user.full_name,
        email: user.email,
        phone: user.phone,
        role: user.role,
        verification_status: user.verification_status,
      },
      token,
    });
  } catch (error) {
    console.error('[login] Database error:', error.message, 'Code:', error.code, 'SQLState:', error.sqlState);
    res.status(500).json({ message: error.message || 'خطأ في الخادم أثناء تسجيل الدخول' });
  }
};

const getPendingUsers = async (req, res) => {
  try {
    const users = await User.getPendingVerifications();
    const decryptedUsers = users.map((user) => ({
      ...user,
      license_no: user.license_no ? decryptText(user.license_no) : null,
      commercial_no: user.commercial_no ? decryptText(user.commercial_no) : null,
    }));
    res.json(decryptedUsers);
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'خطأ في جلب المستخدمين المعلقين' });
  }
};

const setUserVerification = async (req, res) => {
  try {
    const { id } = req.params;
    const { status } = req.body;

    if (!['verified', 'rejected'].includes(status)) {
      return res.status(400).json({ message: 'حالة التحقق غير صحيحة' });
    }

    const updated = await User.updateVerificationStatus(id, status);
    if (!updated) return res.status(404).json({ message: 'المستخدم غير موجود' });

    res.json({ message: 'تم تحديث حالة التحقق', status });
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'خطأ في تحديث الحالة' });
  }
};

const updateProfile = async (req, res) => {
  try {
    const { id } = req.params;
    const { fullName, email, phone, licenseNo, commercialNo } = req.body;

    if (!fullName || fullName.trim() === '' || !email || email.trim() === '' || !phone || phone.trim() === '') {
      return res.status(400).json({ message: 'الاسم، البريد، ورقم الجوال مطلوبين' });
    }

    const user = await User.findById(id);
    if (!user) {
      return res.status(404).json({ message: 'المستخدم غير موجود' });
    }

    const encryptedLicenseNo = typeof licenseNo === 'undefined'
      ? user.license_no
      : licenseNo ? encryptText(licenseNo) : null;
    const encryptedCommercialNo = typeof commercialNo === 'undefined'
      ? user.commercial_no
      : commercialNo ? encryptText(commercialNo) : null;

    const [result] = await pool.execute(
      'UPDATE users SET full_name = ?, email = ?, phone = ?, license_no = ?, commercial_no = ? WHERE id = ?',
      [fullName, email, phone, encryptedLicenseNo, encryptedCommercialNo, id]
    );

    if (result.affectedRows === 0) {
      return res.status(404).json({ message: 'المستخدم غير موجود' });
    }

    res.json({ message: 'تم تحديث البيانات بنجاح' });
  } catch (error) {
    console.error('Profile update error:', error);
    res.status(500).json({ message: 'خطأ في تحديث البيانات' });
  }
};

const getProfile = async (req, res) => {
  try {
    const { id } = req.params;
    const user = await User.findById(id);
    if (!user) {
      return res.status(404).json({ message: 'المستخدم غير موجود' });
    }

    const licenseNo = user.license_no && user.license_no.trim() !== ''
      ? decryptText(user.license_no)
      : null;
    const commercialNo = user.commercial_no && user.commercial_no.trim() !== ''
      ? decryptText(user.commercial_no)
      : null;

    res.json({
      id: user.id,
      full_name: user.full_name,
      phone: user.phone,
      role: user.role,
      license_no: licenseNo,
      commercial_no: commercialNo,
      document_path: user.document_path,
      verification_status: user.verification_status,
    });
  } catch (error) {
    console.error('[getProfile] Error:', error.message, 'Stack:', error.stack);
    res.status(500).json({ message: 'خطأ في جلب البيانات' });
  }
};

module.exports = { register, login, getPendingUsers, setUserVerification, updateProfile, getProfile };