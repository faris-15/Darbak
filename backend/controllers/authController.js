const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const pool = require('../config/db');
const User = require('../models/User');
const Wallet = require('../models/Wallet');

const JWT_SECRET = process.env.JWT_SECRET || 'secret_key';

const register = async (req, res) => {
  try {
    const { fullName, email, phone, password, role = 'driver', licenseNo = null, commercialNo = null, documentPath = null, issueDate = null, expiryDate = null } = req.body;

    console.log('[register] Input:', { fullName, email, phone, role, issueDate, expiryDate });

    // Validate required fields
    if (!fullName || fullName.trim() === '') {
      return res.status(400).json({ message: 'الاسم الكامل مطلوب' });
    }
    if (!email || email.trim() === '') {
      return res.status(400).json({ message: 'البريد الإلكتروني مطلوب' });
    }
    if (!phone || phone.trim() === '') {
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
    if (role === 'shipper' && (!commercialNo || commercialNo.trim() === '')) {
      return res.status(400).json({ message: 'رقم السجل التجاري مطلوب للشاحنين' });
    }

    const existing = await User.findByPhoneOrEmail(phone) || await User.findByPhoneOrEmail(email);
    if (existing) {
      return res.status(400).json({ message: 'البريد أو رقم الجوال مستخدم بالفعل' });
    }

    const hashed = await bcrypt.hash(password, 10);
    const user = await User.create({ fullName, email, phone, password: hashed, role, licenseNo, commercialNo, documentPath, issueDate, expiryDate });
    await Wallet.createForUser(user.id);

    const token = jwt.sign({ id: user.id, role }, JWT_SECRET, { expiresIn: '30d' });
    console.log('[register] Success:', { userId: user.id, role });
    res.status(201).json({ user, token });
  } catch (error) {
    console.error('[register] Database error:', error.message, 'Code:', error.code, 'SQLState:', error.sqlState);
    res.status(500).json({ message: error.message || 'خطأ في الخادم أثناء التسجيل' });
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
    res.json(users);
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

    const [result] = await pool.execute(
      'UPDATE users SET full_name = ?, email = ?, phone = ?, license_no = ?, commercial_no = ? WHERE id = ?',
      [fullName, email, phone, licenseNo, commercialNo, id]
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
    res.json({
      id: user.id,
      full_name: user.full_name,
      phone: user.phone,
      role: user.role,
      license_no: user.license_no,
      commercial_no: user.commercial_no,
      document_path: user.document_path,
      verification_status: user.verification_status
    });
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'خطأ في جلب البيانات' });
  }
};

module.exports = { register, login, getPendingUsers, setUserVerification, updateProfile, getProfile };