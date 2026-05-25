const express = require('express');
const { body, validationResult } = require('express-validator');
const { requireAuth, requireKybVerifiedIfDriverOrShipper } = require('../middleware/authMiddleware');
const {
  getShipmentChat,
  sendShipmentMessage,
  sendShipmentMediaMessage,
  sendShipmentLocationMessage,
  listMyConversations,
  markShipmentMessagesDelivered,
  markShipmentMessagesRead,
} = require('../controllers/chatController');
const { chatMediaUpload, sanitizeApiErrorMessage } = require('../utils/s3Config');

const router = express.Router();

const handleChatMediaUpload = (req, res, next) => {
  chatMediaUpload.single('media')(req, res, (error) => {
    if (!error) return next();
    const message = sanitizeApiErrorMessage(error.message) || 'تعذر رفع الوسائط';
    return res.status(400).json({ message });
  });
};

router.get('/conversations/me', requireAuth, listMyConversations);

router.get('/:shipmentId', requireAuth, getShipmentChat);

router.post(
  '/:shipmentId/media',
  requireAuth,
  requireKybVerifiedIfDriverOrShipper,
  handleChatMediaUpload,
  [
    body('receiverId').isInt({ min: 1 }),
    body('caption').optional().isString(),
    body('messageType').optional().isIn(['image', 'video']),
  ],
  (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ errors: errors.array() });
    }
    return sendShipmentMediaMessage(req, res);
  }
);

router.post(
  '/:shipmentId/location',
  requireAuth,
  requireKybVerifiedIfDriverOrShipper,
  [
    body('receiverId').isInt({ min: 1 }),
    body('latitude').isFloat({ min: -90, max: 90 }),
    body('longitude').isFloat({ min: -180, max: 180 }),
    body('label').optional().isString(),
  ],
  (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ errors: errors.array() });
    }
    return sendShipmentLocationMessage(req, res);
  }
);

router.post(
  '/:shipmentId/delivered',
  requireAuth,
  [body('messageIds').optional().isArray()],
  (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ errors: errors.array() });
    }
    return markShipmentMessagesDelivered(req, res);
  }
);

router.post(
  '/:shipmentId/read',
  requireAuth,
  [body('messageIds').optional().isArray()],
  (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ errors: errors.array() });
    }
    return markShipmentMessagesRead(req, res);
  }
);

router.post(
  '/send',
  requireAuth,
  requireKybVerifiedIfDriverOrShipper,
  [
    body('shipmentId').isInt({ min: 1 }),
    body('receiverId').isInt({ min: 1 }),
    body('message').isString().notEmpty(),
  ],
  (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ errors: errors.array() });
    }
    return sendShipmentMessage(req, res);
  }
);

module.exports = router;
