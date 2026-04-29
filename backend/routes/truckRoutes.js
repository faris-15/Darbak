const express = require('express');
const { body, validationResult } = require('express-validator');
const { registerTruck, getTruckByDriver, updateTruck, deleteTruck, listPendingTrucks, verifyTruck } = require('../controllers/truckController');
const { requireAuth } = require('../middleware/authMiddleware');
const router = express.Router();

const addTruckValidators = [
  body('plate_number').notEmpty(),
  body('isthimara_no').notEmpty(),
  body('truck_type').notEmpty(),
  body('capacity_kg').optional().isFloat({ min: 0 }),
];

router.post('/register', requireAuth, addTruckValidators, (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) return res.status(400).json({ errors: errors.array() });
  registerTruck(req, res);
});

router.post('/add', requireAuth, addTruckValidators, (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) return res.status(400).json({ errors: errors.array() });
  registerTruck(req, res);
});

router.get('/my', requireAuth, getTruckByDriver);

router.put(
  '/:truckId',
  [
    body('isthimara_no').optional().notEmpty(),
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

router.delete('/:truckId', requireAuth, deleteTruck);

router.get('/admin/pending', requireAuth, listPendingTrucks);
router.post('/admin/:truckId/verify', requireAuth, [body('status').isIn(['verified', 'rejected'])], (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) return res.status(400).json({ errors: errors.array() });
  verifyTruck(req, res);
});

module.exports = router;
