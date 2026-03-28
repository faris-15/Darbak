const express = require('express');
const { body, validationResult } = require('express-validator');
const { register, login } = require('../controllers/authController');
const router = express.Router();

router.post(
  '/register',
  [
    body('name').notEmpty(),
    body('email').isEmail(),
    body('password').isLength({ min: 6 }),
    body('role').isIn(['driver', 'shipper']),
  ],
  (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) return res.status(400).json({ errors: errors.array() });
    register(req, res);
  }
);

router.post(
  '/login',
  [body('email').isEmail(), body('password').notEmpty()],
  (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) return res.status(400).json({ errors: errors.array() });
    login(req, res);
  }
);

module.exports = router;
