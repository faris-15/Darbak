const express = require('express');
const { body, validationResult } = require('express-validator');
const { registerTruck, getTruckByDriver, updateTruck, deleteTruck, listPendingTrucks, verifyTruck } = require('../controllers/truckController');
const router = express.Router();

router.post(
  '/register',
  [
    body('user_id').isInt({ min: 1 }),
    body('plate_number').notEmpty(),
    body('truck_type').notEmpty(),
    body('capacity_kg').isFloat({ min: 0 }),
  ],
  (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) return res.status(400).json({ errors: errors.array() });
    registerTruck(req, res);
  }
);

router.get('/:driverId', getTruckByDriver);

router.put(
  '/:truckId',
  [
    body('plate_number').optional().notEmpty(),
    body('truck_type').optional().notEmpty(),
    body('capacity_kg').optional().isFloat({ min: 0 }),
    body('manufacturing_year').optional().isInt({ min: 1900 }),
    body('insurance_expiry_date').optional().isISO8601(),
  ],
  (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) return res.status(400).json({ errors: errors.array() });
    updateTruck(req, res);
  }
);

router.delete('/:truckId', deleteTruck);

router.get('/admin/pending', listPendingTrucks);
router.post('/admin/:truckId/verify', [body('status').isIn(['verified', 'rejected'])], (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) return res.status(400).json({ errors: errors.array() });
  verifyTruck(req, res);
});

module.exports = router;
