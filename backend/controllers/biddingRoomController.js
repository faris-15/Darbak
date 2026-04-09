const BiddingRoom = require('../models/BiddingRoom');
const Bid = require('../models/Bid');
const Notification = require('../models/Notification');

const enterBiddingRoom = async (req, res) => {
  try {
    const { shipmentId } = req.params;
    const { driverId } = req.body;

    console.log('Enter Room Data:', { shipmentId, driverId });

    if (!shipmentId || !driverId) {
      return res.status(400).json({ message: 'shipmentId و driverId مطلوبان' });
    }

    const room = await BiddingRoom.findByShipmentId(shipmentId);
    if (!room) {
      return res.status(404).json({ message: 'غرفة المناقصة غير موجودة' });
    }

    if (room.room_status !== 'open') {
      return res.status(400).json({ message: 'هذه الغرفة مغلقة' });
    }

    // Check if driver is already in another room
    const activeRooms = await BiddingRoom.getActiveRoomsForDriver(driverId);
    if (activeRooms.length > 0) {
      return res.status(403).json({
        message: 'أنت بالفعل في غرفة مناقصة أخرى. يرجى مغادرة الغرفة الأخرى أولاً.',
        activeRoom: activeRooms[0],
      });
    }

    await BiddingRoom.enterRoom(shipmentId, driverId);
    const updatedRoom = await BiddingRoom.findByShipmentId(shipmentId);

    res.json({ message: 'دخلت الغرفة بنجاح', room: updatedRoom });
  } catch (error) {
    console.error('Enter room error:', error);
    res.status(500).json({ message: error.message || 'خطأ في الدخول للغرفة' });
  }
};

const exitBiddingRoom = async (req, res) => {
  try {
    const { shipmentId } = req.params;
    const { driverId } = req.body;

    const room = await BiddingRoom.findByShipmentId(shipmentId);
    if (!room) {
      return res.status(404).json({ message: 'غرفة المناقصة غير موجودة' });
    }

    if (room.lowest_bidder_id == driverId) {
      return res.status(403).json({
        message: 'أنت الفائز الحالي بأقل سعر. لا يمكنك مغادرة الغرفة الآن.',
      });
    }

    await BiddingRoom.exitRoom(shipmentId, driverId);

    // Retract all bids from this driver (if not lowest)
    const driverBids = await Bid.findByShipmentAndDriver(shipmentId, driverId);
    for (const bid of driverBids) {
      if (bid.bid_status === 'pending') {
        await Bid.setStatus(bid.id, 'rejected');
      }
    }

    const updatedRoom = await BiddingRoom.findByShipmentId(shipmentId);
    res.json({ message: 'غادرت الغرفة بنجاح. تم إلغاء جميع عروضك.', room: updatedRoom });
  } catch (error) {
    console.error('Exit room error:', error);
    res.status(500).json({ message: error.message || 'خطأ في مغادرة الغرفة' });
  }
};

const getRoomStatus = async (req, res) => {
  try {
    const { shipmentId } = req.params;

    const room = await BiddingRoom.findByShipmentId(shipmentId);
    if (!room) {
      return res.status(404).json({ message: 'غرفة المناقصة غير موجودة' });
    }

    res.json(room);
  } catch (error) {
    console.error('Get room status error:', error);
    res.status(500).json({ message: 'خطأ في جلب حالة الغرفة' });
  }
};

module.exports = { enterBiddingRoom, exitBiddingRoom, getRoomStatus };
