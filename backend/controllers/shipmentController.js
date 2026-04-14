const Shipment = require('../models/Shipment');
const Bid = require('../models/Bid');
const Wallet = require('../models/Wallet');
const User = require('../models/User');
const Notification = require('../models/Notification');

const createShipment = async (req, res) => {
  try {
    const { shipperId, weightKg, cargoDescription, pickupAddress, dropoffAddress, basePrice, expectedDeliveryDate, period } = req.body;

    console.log('[createShipment] Input:', { shipperId, weightKg, period, basePrice, expectedDeliveryDate });

    // Validate all required fields
    if (!shipperId || !weightKg || !pickupAddress || !dropoffAddress || !basePrice || !expectedDeliveryDate || !period) {
      return res.status(400).json({ message: 'جميع الحقول مطلوبة' });
    }

    // Validate shipper exists and is of type 'shipper'
    const shipper = await User.findById(shipperId);
    if (!shipper) {
      return res.status(404).json({ message: 'المستخدم غير موجود' });
    }
    if (shipper.role !== 'shipper') {
      return res.status(403).json({ message: 'فقط الشاحنون يمكنهم إنشاء شحنات' });
    }

    // Validate price
    if (Number(basePrice) <= 0) {
      return res.status(400).json({ message: 'السعر الأساسي يجب أن يكون أكبر من صفر' });
    }

    // Validate weight
    if (Number(weightKg) <= 0) {
      return res.status(400).json({ message: 'الوزن يجب أن يكون أكبر من صفر' });
    }

    // Create shipment
    const shipment = await Shipment.create({
      shipperId,
      weightKg: Number(weightKg),
      cargoDescription,
      pickupAddress,
      dropoffAddress,
      basePrice: Number(basePrice),
      expectedDeliveryDate,
      period,
    });

    console.log('[createShipment] Success:', { shipmentId: shipment.id, period });
    res.status(201).json(shipment);
  } catch (error) {
    console.error('[createShipment] Database error:', error.message, 'Code:', error.code, 'SQLState:', error.sqlState);
    res.status(500).json({ message: error.message || 'خطأ في إنشاء الشحنة' });
  }
};

const listShipments = async (req, res) => {
  try {
    const shipments = await Shipment.list();
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

module.exports = { createShipment, listShipments, getShipment, completeDelivery };