const express = require('express');
const { body, validationResult } = require('express-validator');
const { postMessage, getConversation } = require('../controllers/conversationController');

const router = express.Router();

router.post(
  '/',
  [
    body('shipmentId').isInt(),
    body('senderId').isInt(),
    body('receiverId').isInt(),
    body('message').notEmpty(),
  ],
  (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) return res.status(400).json({ errors: errors.array() });
    postMessage(req, res);
  }
);

router.get('/shipment/:shipmentId', getConversation);

module.exports = router;
