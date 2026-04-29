const Bid = require('../models/Bid');
const Shipment = require('../models/Shipment');
const Notification = require('../models/Notification');
const { decryptText } = require('../utils/encryption');
const pool = require('../config/db');

const createBid = async (req, res) => {
  try {
    const { shipmentId, bidAmount, estimatedDays } = req.body;
    const driverId = req.user?.id;

    console.log('[Bid.createBid] Input:', { shipmentId, driverId, bidAmount, estimatedDays });

    // Validate required fields
    if (!shipmentId || !driverId || !bidAmount || !estimatedDays) {
      return res.status(400).json({ message: 'جميع الحقول مطلوبة' });
    }
    if (req.user?.role !== 'driver') {
      return res.status(403).json({ message: 'فقط السائق يمكنه تقديم عرض' });
    }

    // Check shipment exists and is in bidding status
    const shipment = await Shipment.findById(shipmentId);
    if (!shipment) {
      return res.status(404).json({ message: 'الشحنة غير موجودة' });
    }

    if (shipment.status !== 'bidding' && shipment.status !== 'pending') {
      return res.status(400).json({ message: 'الشحنة غير متاحة للتقديم عليها' });
    }
    if (shipment.auction_end_time && new Date(shipment.auction_end_time) <= new Date()) {
      return res.status(400).json({ message: 'انتهى وقت المزاد لهذه الشحنة' });
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

    const bids = await Bid.findByShipmentWithDriver(shipmentId);
    
    console.log('[Bid.getBidsByShipment] Raw bids from DB:', JSON.stringify(bids, null, 2));

    // Decrypt driver license_no for each bid
    const bidsWithDecryption = bids.map(bid => {
      console.log('Original Data from DB:', bid.license_no);
      const rawLicense = bid.license_no;
      let decryptedLicense = null;
      if (rawLicense !== null && rawLicense !== undefined && rawLicense !== '') {
        try {
          decryptedLicense = decryptText(rawLicense);
        } catch (error) {
          console.error('[Bid.getBidsByShipment] Decryption failed for bid', bid.id, ':', error.message);
          decryptedLicense = rawLicense; // Return original if decryption fails
        }
      }
      const decrypted = {
        ...bid,
        license_no: decryptedLicense,
      };
      console.log('[Bid.getBidsByShipment] Bid:', decrypted.id, 'Driver:', decrypted.driver_name);
      return decrypted;
    });

    const responseData = bidsWithDecryption.map((bid) => ({
      ...bid,
      driver_name: bid.driver_name || bid.full_name || bid.fullName || 'سائق',
      bid_amount: parseFloat(bid.bid_amount) || 0.0,
      estimated_days: parseInt(bid.estimated_days) || 0,
      driver_rating: bid.driver_rating !== null ? Number(bid.driver_rating) : null,
      rating_count: bid.rating_count !== null ? Number(bid.rating_count) : null,
    }));

    console.log('[Bid.getBidsByShipment] Found', responseData.length, 'bids');
    console.log('Sending to Flutter:', JSON.stringify(responseData, null, 2));
    res.json(responseData);
  } catch (error) {
    console.error('[Bid.getBidsByShipment] Database error:', error.message, 'Code:', error.code, 'SQLState:', error.sqlState);
    res.status(500).json({ message: error.message || 'خطأ في جلب العروض' });
  }
};

const acceptBid = async (req, res) => {
  try {
    const { bidId } = req.params;

    console.log('[Bid.acceptBid] Accepting bid:', bidId);

    if (!bidId || isNaN(Number(bidId))) {
      console.warn('[Bid.acceptBid] Invalid bidId:', bidId);
      return res.status(400).json({ message: 'رقم العرض غير صالح' });
    }

    // Validate bid exists
    const bid = await Bid.findById(bidId);
    if (!bid) {
      console.warn('[Bid.acceptBid] Bid not found:', bidId);
      return res.status(404).json({ message: 'العرض غير موجود' });
    }

    console.log('[Bid.acceptBid] Bid found:', bid.id, 'Status:', bid.bid_status);

    // Check bid is in pending status
    if (bid.bid_status !== 'pending') {
      console.warn('[Bid.acceptBid] Bid not in pending status:', bid.bid_status);
      return res.status(400).json({ message: 'لا يمكن قبول هذا العرض' });
    }

    const shipmentId = bid.shipment_id;
    const driverId = bid.driver_id;
    if (req.user?.role !== 'shipper') {
      return res.status(403).json({ message: 'فقط الشاحن يمكنه قبول العرض' });
    }

    if (!shipmentId || !driverId) {
      console.error('[Bid.acceptBid] Missing required IDs:', { shipmentId, driverId });
      return res.status(400).json({ message: 'بيانات الشحنة أو السائق غير مكتملة' });
    }

    // Check shipment exists and is in bidding status
    const shipment = await Shipment.findById(shipmentId);
    if (!shipment) {
      console.warn('[Bid.acceptBid] Shipment not found:', shipmentId);
      return res.status(404).json({ message: 'الشحنة غير موجودة' });
    }

    console.log('[Bid.acceptBid] Shipment found:', shipment.id, 'Status:', shipment.status);

    if (shipment.status !== 'bidding') {
      console.warn('[Bid.acceptBid] Shipment not in bidding status:', shipment.status);
      return res.status(400).json({ message: 'الشحنة لا يمكن تعيين سائق لها' });
    }
    if (Number(shipment.shipper_id) !== Number(req.user.id)) {
      return res.status(403).json({ message: 'لا يمكنك قبول عروض هذه الشحنة' });
    }

    // Start transaction to ensure atomicity
    const connection = await pool.getConnection();
    try {
      await connection.beginTransaction();
      console.log('[Bid.acceptBid] Transaction started');

      // A. Update target bid to accepted
      const [updateBidResult] = await connection.execute(
        'UPDATE bids SET bid_status = ? WHERE id = ?',
        ['accepted', bidId]
      );
      console.log('[Bid.acceptBid] Updated target bid, affected rows:', updateBidResult.affectedRows);
      if (!updateBidResult.affectedRows) {
        throw new Error(`Failed to update bid status for bidId=${bidId}`);
      }

      // B. Update all other bids to rejected
      const [rejectBidsResult] = await connection.execute(
        'UPDATE bids SET bid_status = ? WHERE shipment_id = ? AND id != ?',
        ['rejected', shipmentId, bidId]
      );
      console.log('[Bid.acceptBid] Rejected other bids, affected rows:', rejectBidsResult.affectedRows);

      // C. Update shipment to assigned with driver_id
      const [updateShipmentResult] = await connection.execute(
        'UPDATE shipments SET status = ?, driver_id = ? WHERE id = ?',
        ['assigned', driverId, shipmentId]
      );
      console.log('[Bid.acceptBid] Updated shipment, affected rows:', updateShipmentResult.affectedRows);

      await connection.commit();
      console.log('[Bid.acceptBid] Transaction committed successfully');

      // Notify driver of acceptance
      try {
        await Notification.create({
          userId: driverId,
          notificationType: 'bid_accepted',
          title: 'تم قبول عرضك',
          message: `تم قبول عرضك للشحنة رقم ${shipmentId}`,
          relatedShipmentId: shipmentId,
          relatedBidId: bidId,
        });
        console.log('[Bid.acceptBid] Driver acceptance notification sent');
      } catch (notifError) {
        console.warn('[Bid.acceptBid] Notification error:', notifError.message);
      }

      // Get other drivers for rejection notifications
      const [otherBids] = await pool.execute(
        'SELECT DISTINCT driver_id FROM bids WHERE shipment_id = ? AND id != ? AND bid_status = ?',
        [shipmentId, bidId, 'rejected']
      );

      // Notify rejected drivers
      for (const otherBid of otherBids) {
        try {
          await Notification.create({
            userId: otherBid.driver_id,
            notificationType: 'bid_rejected',
            title: 'تم رفض عرضك',
            message: `تم اختيار عرض آخر للشحنة رقم ${shipmentId}`,
            relatedShipmentId: shipmentId,
          });
        } catch (notifError) {
          console.warn('[Bid.acceptBid] Rejection notification error:', notifError.message);
        }
      }

      console.log('[Bid.acceptBid] Rejection notifications sent to', otherBids.length, 'drivers');

      return res.status(200).json({
        success: true,
        message: 'تم قبول العرض بنجاح',
        bidId,
        shipmentId,
        driverId,
        status: 'accepted',
      });
    } finally {
      await connection.release();
      console.log('[Bid.acceptBid] Database connection released');
    }
  } catch (error) {
    console.error('[Bid.acceptBid] Error:', error.message, 'Code:', error.code, 'SQLState:', error.sqlState, 'Stack:', error.stack);
    return res.status(500).json({ 
      success: false,
      message: error.message || 'خطأ في قبول العرض' 
    });
  }
};

module.exports = { createBid, getBidsByShipment, acceptBid };