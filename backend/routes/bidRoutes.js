const express = require('express');
const { body, validationResult } = require('express-validator');
const { createBid, getBidsByShipment, acceptBid, getMyActiveBid, withdrawMyPendingBid } = require('../controllers/bidController');
const { requireAuth, requireKybVerifiedIfDriverOrShipper } = require('../middleware/authMiddleware');

const router = express.Router();

router.get('/me/active', requireAuth, getMyActiveBid);
router.post('/me/withdraw', requireAuth, withdrawMyPendingBid);

router.post(
  '/',
  requireAuth,
  requireKybVerifiedIfDriverOrShipper,
  [
    body('shipmentId').isInt(),
    body('bidAmount').isFloat({ gt: 0, max: 99999999.99 }),
    body('estimatedDays').isInt({ min: 1, max: 365 }),
  ],
  (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) return res.status(400).json({ errors: errors.array() });
    createBid(req, res);
  }
);

router.get('/shipment/:shipmentId', getBidsByShipment);

router.post('/:bidId/accept', requireAuth, requireKybVerifiedIfDriverOrShipper, acceptBid);

module.exports = router;
