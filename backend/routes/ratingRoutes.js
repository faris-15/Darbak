const express = require('express');
const { body, validationResult } = require('express-validator');
const { addRating, getUserRatings, updateRating, deleteRating } = require('../controllers/ratingController');
const { requireAuth, requireKybVerifiedIfDriverOrShipper } = require('../middleware/authMiddleware');
const router = express.Router();

const validationErrorResponse = (res, errors) =>
  res.status(400).json({
    message: 'بيانات التقييم غير صحيحة',
    errors: errors.array(),
  });

router.post(
  '/',
  requireAuth,
  requireKybVerifiedIfDriverOrShipper,
  [
    body('shipment_id').isInt({ min: 1 }),
    body('rated_id').isInt({ min: 1 }),
    body('stars').isInt({ min: 1, max: 5 }),
    body('comment').optional().isString(),
  ],
  (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) return validationErrorResponse(res, errors);
    addRating(req, res);
  }
);

router.get('/user/:userId', getUserRatings);

router.put(
  '/:ratingId',
  requireAuth,
  requireKybVerifiedIfDriverOrShipper,
  [
    body('stars').isInt({ min: 1, max: 5 }),
    body('comment').optional().isString(),
  ],
  (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) return validationErrorResponse(res, errors);
    updateRating(req, res);
  }
);

router.delete('/:ratingId', requireAuth, requireKybVerifiedIfDriverOrShipper, deleteRating);

module.exports = router;
