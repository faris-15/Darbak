const express = require('express');
const { getNotifications, markAsRead, markAllAsRead, deleteNotification } = require('../controllers/notificationController');
const router = express.Router();

router.get('/user/:userId', getNotifications);
router.post('/:notificationId/read', markAsRead);
router.post('/user/:userId/read-all', markAllAsRead);
router.delete('/:notificationId', deleteNotification);

module.exports = router;
