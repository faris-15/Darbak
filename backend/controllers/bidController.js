const Bid = require('../models/Bid');
const Shipment = require('../models/Shipment');
const BiddingRoom = require('../models/BiddingRoom');
const Notification = require('../models/Notification');

const createBid = async (req, res) => {
  try {
    const { shipmentId, driverId, bidAmount, estimatedDays } = req.body;

    console.log('Bid Data Received:', { shipmentId, driverId, bidAmount, estimatedDays });

    const shipment = await Shipment.findById(shipmentId);
    if (!shipment) return res.status(404).json({ message: 'الشحنة غير موجودة' });
    if (shipment.status !== 'bidding' && shipment.status !== 'pending') {
      return res.status(400).json({ message: 'الشحنة غير متاحة للتقديم عليها' });
    }

    // Check if driver is in the bidding room
    const room = await BiddingRoom.findByShipmentId(shipmentId);
    if (!room) {
      return res.status(404).json({ message: 'غرفة المناقصة غير موجودة' });
    }

    if (room.active_driver_id != driverId) {
      return res.status(403).json({ message: 'يجب أن تدخل الغرفة أولاً قبل تقديم عرض' });
    }

    if (Number(bidAmount) > Number(shipment.base_price)) {
      return res.status(400).json({ message: 'يجب أن يكون المبلغ أقل أو يساوي السعر الأساسي' });
    }

    // Check if this is lower than current best bid
    if (room.lowest_bid_amount && Number(bidAmount) >= Number(room.lowest_bid_amount)) {
      return res.status(400).json({ message: 'يجب أن يكون عرضك أقل من أفضل عرض حالي' });
    }

    const bid = await Bid.create({ shipmentId, driverId, bidAmount, estimatedDays });

    // Update room with lowest bid
    await BiddingRoom.updateLowestBid(shipmentId, driverId, bidAmount);

    // Notify shipper of new lower bid
    await Notification.create({
      userId: shipment.shipper_id,
      notificationType: 'new_bid',
      title: 'عرض جديد',
      message: `حصلت على عرض جديد بسعر ${bidAmount} ريال`,
      relatedShipmentId: shipmentId,
      relatedBidId: bid.id,
    });

    res.status(201).json({ ...bid, message: 'تم إضافة عرضك في نظام المناقصة العكسية' });
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'خطأ في تقديم العرض' });
  }
};

const getBidsByShipment = async (req, res) => {
  try {
    const { shipmentId } = req.params;
    const bids = await Bid.findByShipment(shipmentId);
    res.json(bids);
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'خطأ في جلب العروض' });
  }
};

module.exports = { createBid, getBidsByShipment };