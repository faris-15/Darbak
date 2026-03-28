const express = require('express');
const { body, validationResult } = require('express-validator');
const { computePayout } = require('../controllers/payoutController');

const router = express.Router();

router.post(
  '/',
  [
    body('totalAmount').isNumeric(),
    body('edt').isISO8601(),
    body('actualDeliveryDate').isISO8601(),
  ],
  (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) return res.status(400).json({ errors: errors.array() });
    computePayout(req, res);
  }
);

module.exports = router;
