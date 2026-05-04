const express = require('express');
const { body, validationResult } = require('express-validator');
const { register, login, getPendingUsers, setUserVerification, updateProfile, getProfile, updateDeviceToken } = require('../controllers/authController');
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

    // If file was uploaded to S3, multer-s3 adds 'location' or 'key' to req.file
    if (req.file) {
      req.body.documentPath = req.file.key;
    }

    register(req, res);
  }
);

router.post(
  '/login',
  [body('identifier').notEmpty(), body('password').notEmpty()],
  (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) return res.status(400).json({ errors: errors.array() });
    login(req, res);
  }
);

router.get('/admin/pending-users', getPendingUsers);
router.post('/admin/users/:id/verify', [body('status').isIn(['verified', 'rejected'])], (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) return res.status(400).json({ errors: errors.array() });
  setUserVerification(req, res);
});

router.put('/profile/:id', [
  body('fullName').notEmpty(),
  body('email').isEmail(),
  body('phone').notEmpty(),
], (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) return res.status(400).json({ errors: errors.array() });
  updateProfile(req, res);
});

router.get('/profile/:id', getProfile);

router.post('/device-token', requireAuth, updateDeviceToken);

module.exports = router;
