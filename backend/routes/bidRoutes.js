const express = require('express');
const { body, validationResult } = require('express-validator');
const { createBid, getBidsByShipment } = require('../controllers/bidController');

const router = express.Router();

router.post(
  '/',
  [
    body('shipmentId').isInt(),
    body('driverId').isInt(),
    body('bidAmount').isNumeric(),
    body('estimatedDays').isInt(),
  ],
  (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) return res.status(400).json({ errors: errors.array() });
    createBid(req, res);
  }
);

router.get('/shipment/:shipmentId', getBidsByShipment);

module.exports = router;
