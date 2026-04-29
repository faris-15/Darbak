const express = require('express');
const { body, validationResult } = require('express-validator');
const { requireAuth } = require('../middleware/authMiddleware');
const { getShipmentChat, sendShipmentMessage } = require('../controllers/chatController');

const router = express.Router();

router.get('/:shipmentId', requireAuth, getShipmentChat);

router.post(
  '/send',
  requireAuth,
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
