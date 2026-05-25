const express = require('express');
const { requireAuth } = require('../middleware/authMiddleware');
const operatingCardController = require('../controllers/operatingCardController');
const { upload, logS3SdkErrorResponsePreview, sanitizeApiErrorMessage } = require('../utils/s3Config');

const router = express.Router();

const handleUpload = (req, res, next) => {
  upload.single('operatingCard')(req, res, async (err) => {
    if (err) {
      console.error('[Operating Card upload error]:', err);
      await logS3SdkErrorResponsePreview(err);
      return res.status(400).json({
        success: false,
        message: 'خطأ في رفع الملف: ' + sanitizeApiErrorMessage(err.message),
      });
    }
    next();
  });
};

router.get('/', requireAuth, operatingCardController.getOperatingCard);
router.post('/upload', requireAuth, handleUpload, operatingCardController.uploadOperatingCard);
router.delete('/', requireAuth, operatingCardController.deleteOperatingCard);

// Admin
router.put('/verify/:id', requireAuth, operatingCardController.verifyOperatingCard);

module.exports = router;
