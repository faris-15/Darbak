const pool = require('../config/db');
const Bid = require('../models/Bid');
const Shipment = require('../models/Shipment');

/**
 * A "Bidding Room" is the collection of all bids for a single shipment.
 * This controller manages the bidding process for a shipment.
 */

const enterBiddingRoom = async (req, res) => {
  try {
    const { shipmentId } = req.params;
    const { driverId, bidAmount, estimatedDays } = req.body;

    console.log('[BiddingRoom.enterBiddingRoom] Input:', { shipmentId, driverId, bidAmount, estimatedDays });

    // Validate inputs
    if (!shipmentId || !driverId || !bidAmount || !estimatedDays) {
      return res.status(400).json({ message: 'shipmentId, دriverId, bidAmount, estimatedDays مطلوبة' });
    }

    // Verify shipment exists
    const shipment = await Shipment.findById(shipmentId);
    if (!shipment) {
      return res.status(404).json({ message: 'الشحنة غير موجودة' });
    }

    // Check if shipment is still in bidding status
    if (shipment.status !== 'bidding') {
      return res.status(400).json({ message: 'هذه الشحنة لا تقبل عروض جديدة' });
    }

    // Check if driver already has a pending bid for this shipment
    const existingBid = await pool.execute(
      'SELECT * FROM bids WHERE shipment_id = ? AND driver_id = ? AND bid_status = ?',
      [shipmentId, driverId, 'pending']
    );
    const [existingBids] = existingBid;

    if (existingBids && existingBids.length > 0) {
      return res.status(400).json({ message: 'لديك بالفعل عرض معلق لهذه الشحنة' });
    }

    // Place the bid
    const newBid = await Bid.create({
      shipmentId,
      driverId,
      bidAmount: Number(bidAmount),
      estimatedDays: Number(estimatedDays),
    });

    console.log('[BiddingRoom.enterBiddingRoom] Bid placed:', { bidId: newBid.id, bidAmount, driverId });

    // Return the updated room status
    const roomStatus = await _getRoomStatus(shipmentId);
    res.json({ message: 'تم تقديم العرض بنجاح', bid: newBid, room: roomStatus });
  } catch (error) {
    console.error('[BiddingRoom.enterBiddingRoom] Database error:', error.message, 'Code:', error.code, 'SQLState:', error.sqlState);
    res.status(500).json({ message: error.message || 'خطأ في تقديم العرض' });
  }
};

const exitBiddingRoom = async (req, res) => {
  try {
    const { shipmentId } = req.params;
    const { driverId } = req.body;

    console.log('[BiddingRoom.exitBiddingRoom] Input:', { shipmentId, driverId });

    // Find driver's bid for this shipment
    const [driverBids] = await pool.execute(
      'SELECT * FROM bids WHERE shipment_id = ? AND driver_id = ? AND bid_status = ?',
      [shipmentId, driverId, 'pending']
    );

    if (!driverBids || driverBids.length === 0) {
      return res.status(404).json({ message: 'لم نجد عرضاً معلقاً لك في هذه الشحنة' });
    }

    const driverBid = driverBids[0];

    // Get the lowest bid
    const [allBids] = await pool.execute(
      'SELECT * FROM bids WHERE shipment_id = ? AND bid_status = ? ORDER BY bid_amount ASC LIMIT 1',
      [shipmentId, 'pending']
    );

    // Check if driver is the lowest bidder
    if (allBids && allBids.length > 0 && allBids[0].driver_id == driverId) {
      return res.status(403).json({
        message: 'أنت الفائز الحالي بأقل سعر. لا يمكنك مغادرة الغرفة الآن.',
      });
    }

    // Reject the driver's bid
    const updated = await Bid.setStatus(driverBid.id, 'rejected');
    if (!updated) {
      throw new Error('Failed to update bid status');
    }

    console.log('[BiddingRoom.exitBiddingRoom] Bid rejected:', { bidId: driverBid.id, driverId });

    const roomStatus = await _getRoomStatus(shipmentId);
    res.json({ message: 'تم إلغاء عرضك بنجاح', room: roomStatus });
  } catch (error) {
    console.error('[BiddingRoom.exitBiddingRoom] Database error:', error.message, 'Code:', error.code, 'SQLState:', error.sqlState);
    res.status(500).json({ message: error.message || 'خطأ في إلغاء العرض' });
  }
};

const getRoomStatus = async (req, res) => {
  try {
    const { shipmentId } = req.params;

    console.log('[BiddingRoom.getRoomStatus] Fetching status for shipmentId:', shipmentId);

    // Verify shipment exists
    const shipment = await Shipment.findById(shipmentId);
    if (!shipment) {
      return res.status(404).json({ message: 'الشحنة غير موجودة' });
    }

    const roomStatus = await _getRoomStatus(shipmentId);
    console.log('[BiddingRoom.getRoomStatus] Success:', roomStatus);
    res.json(roomStatus);
  } catch (error) {
    console.error('[BiddingRoom.getRoomStatus] Database error:', error.message, 'Code:', error.code, 'SQLState:', error.sqlState);
    res.status(500).json({ message: error.message || 'خطأ في جلب حالة الغرفة' });
  }
};

/**
 * Helper function to get complete room status (all bids for a shipment)
 */
async function _getRoomStatus(shipmentId) {
  try {
    const [allBids] = await pool.execute(
      'SELECT * FROM bids WHERE shipment_id = ? AND bid_status = ? ORDER BY bid_amount ASC',
      [shipmentId, 'pending']
    );

    const lowestBid = allBids && allBids.length > 0 ? allBids[0] : null;
    const totalBidders = allBids ? allBids.length : 0;

    return {
      shipment_id: shipmentId,
      total_bids: totalBidders,
      lowest_bid: lowestBid ? {
        id: lowestBid.id,
        driver_id: lowestBid.driver_id,
        bid_amount: lowestBid.bid_amount,
        estimated_days: lowestBid.estimated_days,
      } : null,
      all_bids: allBids || [],
      room_status: totalBidders > 0 ? 'open' : 'empty',
    };
  } catch (error) {
    console.error('[_getRoomStatus] Database error:', error.message, 'Code:', error.code);
    throw error;
  }
}

module.exports = { enterBiddingRoom, exitBiddingRoom, getRoomStatus };
