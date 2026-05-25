const express = require('express');
const { requireAuth } = require('../middleware/authMiddleware');
const { getUserPublicProfile } = require('../controllers/userController');

const router = express.Router();

router.get('/:id/profile', requireAuth, getUserPublicProfile);

module.exports = router;
