const Shipment = require('../models/Shipment');
const Bid = require('../models/Bid');
const Wallet = require('../models/Wallet');
const User = require('../models/User');
const Notification = require('../models/Notification');
const ShipmentStatus = require('../models/ShipmentStatus');

const OPEN_SHIPMENT_STATUSES = ['pending', 'bidding', 'assigned', 'at_pickup', 'en_route', 'at_dropoff'];
const MAX_OPEN_SHIPMENTS_PER_SHIPPER = 5;

const jsonError = (res, status, code, message) =>
  res.status(status).json({ success: false, code, message });

const createShipment = async (req, res) => {
  try {
    const {
      weightKg,
      cargoDescription,
      pickupAddress,
      dropoffAddress,
      pickupLat,
      pickupLng,
      dropoffLat,
      dropoffLng,
      basePrice,
      expectedDeliveryDate,
      period,
      specialInstructions,
      auctionDurationHours,
    } = req.body;
    const shipperId = req.user?.id;

    console.log('[createShipment] Input:', { shipperId, weightKg, period, basePrice, expectedDeliveryDate });

    // Validate all required fields
    if (!shipperId || !weightKg || !pickupAddress || !dropoffAddress || !basePrice || !expectedDeliveryDate || !period) {
      return jsonError(res, 400, 'VALIDATION_ERROR', 'جميع الحقول مطلوبة');
    }

    const parsedPickupLat = Number(pickupLat);
    const parsedPickupLng = Number(pickupLng);
    const parsedDropoffLat = Number(dropoffLat);
    const parsedDropoffLng = Number(dropoffLng);

    if (
      !Number.isFinite(parsedPickupLat) ||
      !Number.isFinite(parsedPickupLng) ||
      !Number.isFinite(parsedDropoffLat) ||
      !Number.isFinite(parsedDropoffLng)
    ) {
      return jsonError(res, 400, 'VALIDATION_ERROR', 'إحداثيات التحميل والتسليم مطلوبة');
    }

    // Validate shipper exists and is of type 'shipper'
    const shipper = await User.findById(shipperId);
    if (!shipper) {
      return jsonError(res, 404, 'NOT_FOUND', 'المستخدم غير موجود');
    }
    if (shipper.role !== 'shipper') {
      return jsonError(res, 403, 'FORBIDDEN', 'فقط الشاحنون يمكنهم إنشاء شحنات');
    }

    const openCount = await Shipment.countByShipperInStatuses(shipperId, OPEN_SHIPMENT_STATUSES);
    if (openCount >= MAX_OPEN_SHIPMENTS_PER_SHIPPER) {
      return jsonError(
        res,
        400,
        'LIMIT_EXCEEDED',
        'لا يمكنك إضافة أكثر من 5 شحنات نشطة/مفتوحة',
      );
    }

    // Validate price
    if (Number(basePrice) <= 0) {
      return jsonError(res, 400, 'VALIDATION_ERROR', 'السعر الأساسي يجب أن يكون أكبر من صفر');
    }

    // Validate weight
    if (Number(weightKg) <= 0) {
      return jsonError(res, 400, 'VALIDATION_ERROR', 'الوزن يجب أن يكون أكبر من صفر');
    }

    // Create shipment
    const parsedAuctionDuration = Number(auctionDurationHours ?? 24);
    if (!Number.isInteger(parsedAuctionDuration) || parsedAuctionDuration <= 0) {
      return jsonError(res, 400, 'VALIDATION_ERROR', 'مدة المزاد يجب أن تكون بالساعات وبقيمة صحيحة');
    }
    const auctionEndTime = new Date(Date.now() + parsedAuctionDuration * 60 * 60 * 1000);

    const shipment = await Shipment.create({
      shipperId,
      weightKg: Number(weightKg),
      cargoDescription,
      pickupAddress,
      dropoffAddress,
      pickupLat: parsedPickupLat,
      pickupLng: parsedPickupLng,
      dropoffLat: parsedDropoffLat,
      dropoffLng: parsedDropoffLng,
      basePrice: Number(basePrice),
      expectedDeliveryDate,
      period,
      specialInstructions:
        typeof specialInstructions === 'string' &&
        specialInstructions.trim().length > 0
          ? specialInstructions.trim()
          : null,
      auctionDurationHours: parsedAuctionDuration,
      auctionEndTime,
    });

    console.log('[createShipment] Success:', { shipmentId: shipment.id, period });
    res.status(201).json(shipment);
  } catch (error) {
    console.error('[createShipment] Database error:', error.message, 'Code:', error.code, 'SQLState:', error.sqlState);
    return jsonError(
      res,
      500,
      'INTERNAL_ERROR',
      error.message || 'خطأ في إنشاء الشحنة',
    );
  }
};

const listShipments = async (req, res) => {
  try {
    const isShipper = req.user?.role === 'shipper';
    const shipments = isShipper ? await Shipment.listForShipper(req.user.id) : await Shipment.list();
    res.json(shipments);
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'خطأ في جلب الشحنات' });
  }
};

const getShipment = async (req, res) => {
  try {
    const { id } = req.params;
    const shipment = await Shipment.findById(id);
    if (!shipment) return res.status(404).json({ message: 'الشحنة غير موجودة' });
    res.json(shipment);
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'خطأ خادم' });
  }
};

const completeDelivery = async (req, res) => {
  try {
    const { id } = req.params;
    const { bidId, actualDeliveryDate } = req.body;

    const bid = await Bid.findById(bidId);
    if (!bid) return res.status(404).json({ message: 'العرض غير موجود' });
    if (Number(bid.shipment_id) !== Number(id)) return res.status(400).json({ message: 'العرض لا ينتمي لهذه الشحنة' });

    // قبول هذا العرض ورفض الباقي
    await Bid.setStatus(bidId, 'accepted');
    await Bid.rejectOtherBidsForShipment(id, bidId);

    const result = await Shipment.completeDelivery({ shipmentId: id, bidAmount: Number(bid.bid_amount), actualDeliveryDate });

    // إضافة الايراد إلى المحفظة للسائق
    await Wallet.adjustBalance(bid.driver_id, result.final_price);

    res.json({ message: 'تم إكمال التسليم', result });
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'خطأ في إنهاء الشحنة' });
  }
};

const getActiveShipmentsForDriver = async (req, res) => {
  try {
    if (req.user?.role !== 'driver') {
      return res.status(403).json({ message: 'Forbidden' });
    }

    const shipments = await Shipment.listActiveByDriver(req.user.id);
    return res.json(shipments);
  } catch (error) {
    console.error('[getActiveShipmentsForDriver] Error:', error);
    return res.status(500).json({ message: 'خطأ في جلب الشحنات النشطة' });
  }
};

const getShipmentsForDriver = async (req, res) => {
  try {
    if (req.user?.role !== 'driver') {
      return res.status(403).json({ message: 'Forbidden' });
    }

    const shipments = await Shipment.listByDriverPriority(req.user.id);
    return res.json(shipments);
  } catch (error) {
    console.error('[getShipmentsForDriver] Error:', error);
    return res.status(500).json({ message: 'خطأ في جلب رحلات السائق' });
  }
};

const allowedLifecycleStatuses = [
  'assigned',
  'at_pickup',
  'en_route',
  'at_dropoff',
  'delivered',
];

const updateShipmentStatus = async (req, res) => {
  try {
    if (req.user?.role !== 'driver') {
      return res.status(403).json({ message: 'Forbidden' });
    }

    const { id } = req.params;
    const { status, location_lat, location_lng } = req.body;

    if (!allowedLifecycleStatuses.includes(status)) {
      return res.status(400).json({ message: 'حالة الشحنة غير صحيحة' });
    }

    const shipment = await Shipment.findById(id);
    if (!shipment) {
      return res.status(404).json({ message: 'الشحنة غير موجودة' });
    }

    if (Number(shipment.driver_id) !== Number(req.user.id)) {
      return res.status(403).json({ message: 'لا يمكنك تحديث هذه الشحنة' });
    }

    if (status === 'delivered' && !req.file) {
      return res.status(400).json({ message: 'صورة إثبات التسليم مطلوبة' });
    }

    const updated = await Shipment.updateStatus(id, status);
    if (!updated) {
      return res.status(500).json({ message: 'تعذر تحديث الحالة' });
    }

    const photoPath = req.file ? `/uploads/epod/${req.file.filename}` : null;
    const statusRecord = await ShipmentStatus.recordStatus({
      shipment_id: id,
      status,
      location_lat: location_lat ?? null,
      location_lng: location_lng ?? null,
      photo_path: photoPath,
    });

    if (status === 'delivered') {
      await Shipment.setDeliveryMetadata(id, {
        actualDeliveryDate: new Date(),
        podPhotoPath: photoPath,
      });
    }

    return res.json({
      message: 'تم تحديث حالة الشحنة',
      shipment_id: Number(id),
      status,
      history: statusRecord,
    });
  } catch (error) {
    console.error('[updateShipmentStatus] Error:', error);
    return res.status(500).json({ message: 'خطأ في تحديث حالة الشحنة' });
  }
};

module.exports = {
  createShipment,
  listShipments,
  getShipment,
  completeDelivery,
  getActiveShipmentsForDriver,
  getShipmentsForDriver,
  updateShipmentStatus,
};