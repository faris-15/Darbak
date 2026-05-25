/**
 * مسارات المصادقة والملف الشخصي تحت /api/auth
 * تمت إزالة مسارات إعادة تعيين كلمة المرور المحلية؛ استخدم POST /password-reset-request من التطبيق + POST /login-firebase عند الحاجة.
 */
const express = require('express');
const { body, validationResult } = require('express-validator');
const {
  register,
  login,
  loginWithFirebase,
  requestFirebasePasswordReset,
  getPendingUsers,
  setUserVerification,
  updateProfile,
  getProfile,
  updateDeviceToken,
} = require('../controllers/authController');
const { upload, logS3SdkErrorResponsePreview, sanitizeApiErrorMessage } = require('../utils/s3Config');
const { requireAuth } = require('../middleware/authMiddleware');
const router = express.Router();

const handleRegisterUpload = (req, res, next) => {
  upload.single('document')(req, res, async (err) => {
    if (err) {
      console.error('[Multer-S3 Error]:', err);
      await logS3SdkErrorResponsePreview(err);
      return res.status(400).json({
        success: false,
        message: 'خطأ في رفع الملف إلى التخزين: ' + sanitizeApiErrorMessage(err.message),
      });
    }
    next();
  });
};

router.post(
  '/register',
  handleRegisterUpload,
  [
    body('fullName').notEmpty(),
    body('email').isEmail(),
    body('phone').notEmpty(),
    body('password').isLength({ min: 6 }),
    body('role').optional().isIn(['driver', 'shipper', 'admin']),
  ],
  (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) return res.status(400).json({ errors: errors.array() });

    if (req.file) {
      req.body.documentPath = req.file.key;
    }

    register(req, res);
  },
);

router.post(
  '/login',
  [body('identifier').notEmpty(), body('password').notEmpty()],
  (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) return res.status(400).json({ errors: errors.array() });
    login(req, res);
  },
);

const respondValidationErrors = (req, res) => {
  const errors = validationResult(req);
  if (errors.isEmpty()) return false;
  const first = errors.array()[0];
  const message = (first && first.msg) ? String(first.msg) : 'بيانات الطلب غير صحيحة';
  res.status(400).json({ success: false, message, errors: errors.array() });
  return true;
};

router.post(
  '/login-firebase',
  [
    body('idToken').notEmpty().withMessage('رمز المصادقة مطلوب'),
    body('password').optional().isLength({ min: 8 }).withMessage('كلمة المرور يجب أن تكون 8 أحرف على الأقل'),
  ],
  (req, res) => {
    if (respondValidationErrors(req, res)) return;
    loginWithFirebase(req, res);
  },
);

router.post(
  '/password-reset-request',
  [body('email').isEmail().withMessage('بريد غير صالح')],
  (req, res) => {
    if (respondValidationErrors(req, res)) return;
    requestFirebasePasswordReset(req, res);
  },
);

router.get('/admin/pending-users', getPendingUsers);
router.post('/admin/users/:id/verify', [body('status').isIn(['verified', 'rejected'])], (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) return res.status(400).json({ errors: errors.array() });
  setUserVerification(req, res);
});

router.put('/profile/:id', requireAuth, [
  body('fullName').notEmpty(),
  body('email').isEmail(),
  body('phone').notEmpty(),
], (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) return res.status(400).json({ errors: errors.array() });
  updateProfile(req, res);
});

router.get('/profile/:id', requireAuth, getProfile);

router.post('/device-token', requireAuth, updateDeviceToken);

module.exports = router;
