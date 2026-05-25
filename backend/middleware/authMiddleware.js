const jwt = require('jsonwebtoken');
const User = require('../models/User');

const JWT_SECRET = process.env.JWT_SECRET || 'secret_key';

const requireAuth = (req, res, next) => {
  const authHeader = req.headers.authorization || '';
  const token = authHeader.startsWith('Bearer ')
    ? authHeader.slice(7)
    : null;

  if (!token) {
    return res.status(401).json({ message: 'Unauthorized' });
  }

  try {
    const decoded = jwt.verify(token, JWT_SECRET);
    req.user = decoded;
    return next();
  } catch (error) {
    return res.status(401).json({ message: 'Unauthorized' });
  }
};

const requireAdmin = (req, res, next) => {
  if (!req.user || req.user.role !== 'admin') {
    return res.status(403).json({ message: 'Forbidden' });
  }
  return next();
};

/**
 * KYB: للشاحن والسائق — التحقق من `users.verification_status` (موافقة الإدارة على الوثائق).
 * الأدوار الأخرى (مثل admin) تتجاوز الفحص.
 */
const requireKybVerifiedIfDriverOrShipper = async (req, res, next) => {
  try {
    if (!req.user) {
      return res.status(401).json({ message: 'Unauthorized' });
    }
    const role = req.user.role;
    if (role !== 'shipper' && role !== 'driver') {
      return next();
    }

    const user = await User.findById(req.user.id);
    if (!user) {
      return res.status(401).json({ message: 'Unauthorized' });
    }
    if (user.is_active === 0 || user.is_active === false) {
      return res.status(403).json({ message: 'تم تعطيل هذا الحساب. تواصل مع الدعم.' });
    }

    const vs = String(user.verification_status || 'pending');
    if (vs === 'verified') {
      return next();
    }

    const isDriver = role === 'driver';
    const message =
      vs === 'rejected'
        ? isDriver
          ? 'لم تُقبل وثائقك (الرخصة وغيرها). تواصل مع الدعم أو انتظر مراجعة جديدة من الإدارة.'
          : 'لم تُقبل وثائق شركتك بعد. تواصل مع الدعم أو انتظر مراجعة جديدة من الإدارة.'
        : isDriver
          ? 'حسابك قيد مراجعة الوثائق من الإدارة. بعد الموافقة يمكنك تقديم العروض وتحديث حالة الرحلات والمحادثات التشغيلية.'
          : 'حساب شركتك قيد مراجعة الوثائق (السجل التجاري وغيرها). بعد الموافقة من الإدارة يمكنك نشر الشحنات وقبول العروض.';

    return res.status(403).json({
      success: false,
      code: 'KYB_NOT_VERIFIED',
      verification_status: vs,
      message,
    });
  } catch (err) {
    console.error('[requireKybVerifiedIfDriverOrShipper]', err.message);
    return res.status(500).json({ message: 'خطأ في التحقق من حالة الحساب' });
  }
};

module.exports = {
  requireAuth,
  requireAdmin,
  requireKybVerifiedIfDriverOrShipper,
  /** @deprecated استخدم requireKybVerifiedIfDriverOrShipper */
  requireVerifiedShipperIfShipper: requireKybVerifiedIfDriverOrShipper,
};
