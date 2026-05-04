const express = require('express');
const { body, validationResult } = require('express-validator');
const { addRating, getUserRatings, updateRating, deleteRating } = require('../controllers/ratingController');
const { requireAuth } = require('../middleware/authMiddleware');
const router = express.Router();

router.post(
  '/',
  requireAuth,
  [
    body('shipment_id').isInt({ min: 1 }),
    body('rated_id').isInt({ min: 1 }),
    body('stars').isInt({ min: 1, max: 5 }),
    body('comment').optional().isString(),
  ],
  (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) return res.status(400).json({ errors: errors.array() });
    addRating(req, res);
  }
);

router.get('/user/:userId', getUserRatings);

router.put(
  '/:ratingId',
  [
    body('stars').isInt({ min: 1, max: 5 }),
    body('comment').optional().isString(),
  ],
  (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) return res.status(400).json({ errors: errors.array() });
    updateRating(req, res);
  }
);

router.delete('/:ratingId', deleteRating);

module.exports = router;
