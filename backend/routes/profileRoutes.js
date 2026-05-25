const express = require('express');
const { body, validationResult } = require('express-validator');
const { requireAuth } = require('../middleware/authMiddleware');
const {
  getMyProfile,
  updateMyProfile,
  uploadProfileImage,
  removeProfileImage,
} = require('../controllers/profileController');
const {
  profileImageUpload,
  logS3SdkErrorResponsePreview,
  sanitizeApiErrorMessage,
} = require('../utils/s3Config');

const router = express.Router();

const handleProfileImageUpload = (req, res, next) => {
  profileImageUpload.single('profileImage')(req, res, async (err) => {
    if (err) {
      console.error('[Profile image upload error]:', err);
      await logS3SdkErrorResponsePreview(err);
      return res.status(400).json({
        success: false,
        message: 'خطأ في رفع الصورة: ' + sanitizeApiErrorMessage(err.message),
      });
    }
    next();
  });
};

const updateProfileValidators = [
  body('fullName').notEmpty().withMessage('الاسم مطلوب'),
  body('email').isEmail().withMessage('البريد الإلكتروني غير صحيح'),
  body('phone').notEmpty().withMessage('رقم الجوال مطلوب'),
  body('licenseNo').optional({ nullable: true }).isString(),
  body('commercialNo').optional({ nullable: true }).isString(),
];

router.get('/me', requireAuth, getMyProfile);

router.put('/update', requireAuth, updateProfileValidators, (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) return res.status(400).json({ success: false, errors: errors.array() });
  return updateMyProfile(req, res);
});

router.post('/upload-image', requireAuth, handleProfileImageUpload, uploadProfileImage);

router.delete('/remove-image', requireAuth, removeProfileImage);

module.exports = router;
