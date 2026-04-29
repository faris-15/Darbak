const express = require('express');
const path = require('path');
const fs = require('fs');
const multer = require('multer');
const { body, validationResult } = require('express-validator');
const {
  createShipment,
  listShipments,
  getShipment,
  completeDelivery,
  getActiveShipmentsForDriver,
  getShipmentsForDriver,
  updateShipmentStatus,
} = require('../controllers/shipmentController');
const { requireAuth } = require('../middleware/authMiddleware');

const router = express.Router();
const epodUploadDir = path.join(__dirname, '..', 'uploads', 'epod');

if (!fs.existsSync(epodUploadDir)) {
  fs.mkdirSync(epodUploadDir, { recursive: true });
}

const storage = multer.diskStorage({
  destination: (_req, _file, cb) => cb(null, epodUploadDir),
  filename: (req, file, cb) => {
    const ext = path.extname(file.originalname || '.jpg');
    cb(null, `shipment-${req.params.id}-${Date.now()}${ext}`);
  },
});

const upload = multer({
  storage,
  fileFilter: (_req, file, cb) => {
    if (file.mimetype && file.mimetype.startsWith('image/')) {
      cb(null, true);
      return;
    }
    cb(new Error('Only image uploads are allowed'));
  },
  limits: { fileSize: 8 * 1024 * 1024 },
});

router.post(
  '/',
  requireAuth,
  [
    body('weightKg').isNumeric(),
    body('cargoDescription').notEmpty(),
    body('pickupAddress').notEmpty(),
    body('dropoffAddress').notEmpty(),
    body('basePrice').isNumeric(),
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
router.get('/:id', getShipment);
router.patch('/:id/status', requireAuth, upload.single('epodPhoto'), updateShipmentStatus);
router.post('/:id/complete', [body('bidId').isInt(), body('actualDeliveryDate').isISO8601()], (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) return res.status(400).json({ errors: errors.array() });
  completeDelivery(req, res);
});

module.exports = router;
