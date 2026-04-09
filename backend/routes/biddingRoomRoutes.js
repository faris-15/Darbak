const express = require('express');
const router = express.Router();
const { enterBiddingRoom, exitBiddingRoom, getRoomStatus } = require('../controllers/biddingRoomController');

router.post('/rooms/:shipmentId/enter', enterBiddingRoom);
router.post('/rooms/:shipmentId/exit', exitBiddingRoom);
router.get('/rooms/:shipmentId/status', getRoomStatus);

module.exports = router;
