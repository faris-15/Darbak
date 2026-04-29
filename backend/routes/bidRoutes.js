const express = require('express');
const { body, validationResult } = require('express-validator');
const { createBid, getBidsByShipment, acceptBid } = require('../controllers/bidController');
const { requireAuth } = require('../middleware/authMiddleware');

const router = express.Router();

router.post(
  '/',
  requireAuth,
  [
    body('shipmentId').isInt(),
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

router.post('/:bidId/accept', requireAuth, acceptBid);

module.exports = router;
