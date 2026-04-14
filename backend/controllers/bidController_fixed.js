const Bid = require('../models/Bid');
const Shipment = require('../models/Shipment');
const Notification = require('../models/Notification');
const pool = require('../config/db');

const createBid = async (req, res) => {
  try {
    const { shipmentId, driverId, bidAmount, estimatedDays } = req.body;

    console.log('[Bid.createBid] Input:', { shipmentId, driverId, bidAmount, estimatedDays });

    // Validate required fields
    if (!shipmentId || !driverId || !bidAmount || !estimatedDays) {
      return res.status(400).json({ message: 'جميع الحقول مطلوبة' });
    }

    // Check shipment exists and is in bidding status
    const shipment = await Shipment.findById(shipmentId);
    if (!shipment) {
      return res.status(404).json({ message: 'الشحنة غير موجودة' });
    }

    if (shipment.status !== 'bidding' && shipment.status !== 'pending') {
      return res.status(400).json({ message: 'الشحنة غير متاحة للتقديم عليها' });
    }

    // Validate bid amount doesn't exceed base price
    if (Number(bidAmount) > Number(shipment.base_price)) {
      return res.status(400).json({ message: 'يجب أن يكون المبلغ أقل أو يساوي السعر الأساسي' });
    }

    // Check if driver already has a pending bid for this shipment
    const [existingBids] = await pool.execute(
      'SELECT * FROM bids WHERE shipment_id = ? AND driver_id = ? AND bid_status = ?',
      [shipmentId, driverId, 'pending']
    );

    if (existingBids && existingBids.length > 0) {
      return res.status(400).json({ message: 'لديك بالفعل عرض معلق لهذه الشحنة' });
    }

    // Get the current lowest bid for this shipment
    const [lowestBids] = await pool.execute(
      'SELECT * FROM bids WHERE shipment_id = ? AND bid_status = ? ORDER BY bid_amount ASC LIMIT 1',
      [shipmentId, 'pending']
    );

    // Check if this bid is lower than current best bid
    if (lowestBids && lowestBids.length > 0) {
      const currentLowest = lowestBids[0].bid_amount;
      if (Number(bidAmount) >= Number(currentLowest)) {
        return res.status(400).json({
          message: `يجب أن يكون عرضك أقل من أفضل عرض حالي (${currentLowest} ريال)`,
        });
      }
    }

    // Create the bid in the bids table
    const bid = await Bid.create({ shipmentId, driverId, bidAmount, estimatedDays });

    console.log('[Bid.createBid] Bid created:', { bidId: bid.id, driverId, bidAmount });

    // Notify shipper of new bid
    try {
      await Notification.create({
        userId: shipment.shipper_id,
        notificationType: 'new_bid',
        title: 'عرض جديد',
        message: `حصلت على عرض جديد بسعر ${bidAmount} ريال`,
        relatedShipmentId: shipmentId,
        relatedBidId: bid.id,
      });
    } catch (notifError) {
      console.warn('[Bid.createBid] Notification error:', notifError.message);
      // Don't fail the bid creation if notification fails
    }

    res.status(201).json({ 
      ...bid, 
      message: 'تم إضافة عرضك في نظام المناقصة العكسية' 
    });
  } catch (error) {
    console.error('[Bid.createBid] Database error:', error.message, 'Code:', error.code, 'SQLState:', error.sqlState);
    res.status(500).json({ message: error.message || 'خطأ في تقديم العرض' });
  }
};

const getBidsByShipment = async (req, res) => {
  try {
    const { shipmentId } = req.params;

    console.log('[Bid.getBidsByShipment] Fetching bids for shipmentId:', shipmentId);

    const bids = await Bid.findByShipment(shipmentId);
    
    console.log('[Bid.getBidsByShipment] Found', bids.length, 'bids');
    res.json(bids);
  } catch (error) {
    console.error('[Bid.getBidsByShipment] Database error:', error.message, 'Code:', error.code, 'SQLState:', error.sqlState);
    res.status(500).json({ message: error.message || 'خطأ في جلب العروض' });
  }
};

module.exports = { createBid, getBidsByShipment };
