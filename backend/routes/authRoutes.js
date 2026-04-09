const express = require('express');
const { body, validationResult } = require('express-validator');
const { register, login, getPendingUsers, setUserVerification, updateProfile, getProfile } = require('../controllers/authController');
const router = express.Router();

router.post(
  '/register',
  [
    body('fullName').notEmpty(),
    body('email').isEmail(),
    body('phone').notEmpty(),
    body('password').isLength({ min: 6 }),
    body('role').optional().isIn(['driver', 'shipper', 'admin']),
  ],
  (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) return res.status(400).json({ errors: errors.array() });
    register(req, res);
  }
);

router.post(
  '/login',
  [body('identifier').notEmpty(), body('password').notEmpty()],
  (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) return res.status(400).json({ errors: errors.array() });
    login(req, res);
  }
);

router.get('/admin/pending-users', getPendingUsers);
router.post('/admin/users/:id/verify', [body('status').isIn(['verified', 'rejected'])], (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) return res.status(400).json({ errors: errors.array() });
  setUserVerification(req, res);
});

router.put('/profile/:id', [
  body('fullName').notEmpty(),
  body('phone').notEmpty(),
], (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) return res.status(400).json({ errors: errors.array() });
  updateProfile(req, res);
});

router.get('/profile/:id', getProfile);

module.exports = router;
