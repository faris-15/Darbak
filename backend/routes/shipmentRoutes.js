const express = require('express');
const { body, validationResult } = require('express-validator');
const {
  createShipment,
  listShipments,
  getShipment,
  getShipmentContractPdfUrl,
  recordLiveLocation,
  completeDelivery,
  getActiveShipmentsForDriver,
  getShipmentsForDriver,
  updateShipmentStatus,
} = require('../controllers/shipmentController');
const { requireAuth, requireKybVerifiedIfDriverOrShipper } = require('../middleware/authMiddleware');
const { upload, logS3SdkErrorResponsePreview, sanitizeApiErrorMessage } = require('../utils/s3Config'); // استيراد إعدادات S3 الجاهزة

const router = express.Router();

// Middleware لمعالجة أخطاء Multer-S3 وإرجاع JSON
const handleUpload = (req, res, next) => {
  // نقوم بتمرير 'epodPhoto' كاسم للحقل المتوقع من التطبيق
  upload.single('epodPhoto')(req, res, async (err) => {
    if (err) {
      console.error('[Multer-S3 Error]:', err);
      await logS3SdkErrorResponsePreview(err);
      return res.status(400).json({
        success: false,
        message: 'خطأ في رفع الملف إلى S3: ' + sanitizeApiErrorMessage(err.message),
      });
    }

    // إذا تم الرفع بنجاح، multer-s3 يضيف المعلومات لـ req.file
    if (req.file) {
      // نضع المفتاح (key) في body لسهولة استخدامه في الكنترولر
      req.body.documentPath = req.file.key;
    }
    next();
  });
};

const maybeMultipart = (req, res, next) => {
  const ct = req.headers['content-type'] || '';
  if (ct.includes('multipart/form-data')) {
    return handleUpload(req, res, next);
  }
  return next();
};

router.post(
  '/',
  requireAuth,
  requireKybVerifiedIfDriverOrShipper,
  [
    body('weightKg').isNumeric(),
    body('cargoDescription').notEmpty(),
    body('pickupAddress').notEmpty(),
    body('dropoffAddress').notEmpty(),
    body('suggestedPrice').optional({ nullable: true }).isNumeric(),
    body('basePrice').optional({ nullable: true }).isNumeric(),
    body().custom((_, { req }) => {
      if (req.body.suggestedPrice === undefined && req.body.basePrice === undefined) {
        throw new Error('السعر المقترح مطلوب');
      }
      return true;
    }),
    body('expectedDeliveryDate').isISO8601(),
  ],
  (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) return res.status(400).json({ errors: errors.array() });
    createShipment(req, res);
  }
);

router.get('/', listShipments);
router.get('/driver', requireAuth, getShipmentsForDriver);
router.get('/driver/active', requireAuth, getActiveShipmentsForDriver);
router.get('/:id/contract', requireAuth, getShipmentContractPdfUrl);
router.post(
  '/:id/live-location',
  requireAuth,
  requireKybVerifiedIfDriverOrShipper,
  recordLiveLocation,
);
router.get('/:id', getShipment);

// استخدام S3 للرفع عند تحديث الحالة (multipart فقط عند وجود ملف)
router.patch(
  '/:id/status',
  requireAuth,
  requireKybVerifiedIfDriverOrShipper,
  maybeMultipart,
  updateShipmentStatus,
);

router.post('/:id/complete', [body('bidId').isInt(), body('actualDeliveryDate').isISO8601()], (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) return res.status(400).json({ errors: errors.array() });
  completeDelivery(req, res);
});

module.exports = router;
