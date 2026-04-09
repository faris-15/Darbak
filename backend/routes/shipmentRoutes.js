const express = require('express');
const { body, validationResult } = require('express-validator');
const { createShipment, listShipments, getShipment, completeDelivery } = require('../controllers/shipmentController');

const router = express.Router();

router.post(
  '/',
  [
    body('shipperId').isInt(),
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
router.get('/:id', getShipment);
router.post('/:id/complete', [body('bidId').isInt(), body('actualDeliveryDate').isISO8601()], (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) return res.status(400).json({ errors: errors.array() });
  completeDelivery(req, res);
});

module.exports = router;
