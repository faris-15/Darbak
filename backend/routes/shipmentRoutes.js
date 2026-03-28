const express = require('express');
const { body, validationResult } = require('express-validator');
const { createShipment, listShipments, getShipment } = require('../controllers/shipmentController');

const router = express.Router();

router.post(
  '/',
  [
    body('shipperId').isInt(),
    body('origin').notEmpty(),
    body('destination').notEmpty(),
    body('freightType').notEmpty(),
    body('weight').isNumeric(),
    body('value').isNumeric(),
    body('edt').isISO8601(),
  ],
  (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) return res.status(400).json({ errors: errors.array() });
    createShipment(req, res);
  }
);

router.get('/', listShipments);
router.get('/:id', getShipment);

module.exports = router;
