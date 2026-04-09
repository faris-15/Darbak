const ShipmentStatus = require('../models/ShipmentStatus');
const Shipment = require('../models/Shipment');

const recordStatus = async (req, res) => {
  try {
    const {
      shipment_id,
      status,
      location_lat,
      location_lng,
      photo_path,
    } = req.body;

    // Validate required fields
    if (!shipment_id || !status) {
      return res
        .status(400)
        .json({ message: 'shipment_id و status مطلوبة' });
    }

    // Check if shipment exists
    const shipment = await Shipment.findById(shipment_id);
    if (!shipment) {
      return res.status(404).json({ message: 'الشحنة غير موجودة' });
    }

    // Record the status change
    const statusRecord = await ShipmentStatus.recordStatus({
      shipment_id,
      status,
      location_lat,
      location_lng,
      photo_path,
    });

    // Update shipment status for the main shipment record as well
    const allowedStates = ['pickup_arrived', 'en_route', 'dropoff_arrived', 'pod_required', 'delivered'];
    if (allowedStates.includes(status)) {
      await Shipment.updateStatus(shipment_id, status);
    }

    res.status(201).json(statusRecord);
  } catch (error) {
    console.error('Record shipment status error:', error);
    res.status(500).json({ message: 'خطأ في تسجيل حالة الشحنة' });
  }
};

const getStatusHistory = async (req, res) => {
  try {
    const { shipment_id } = req.params;

    // Check if shipment exists
    const shipment = await Shipment.findById(shipment_id);
    if (!shipment) {
      return res.status(404).json({ message: 'الشحنة غير موجودة' });
    }

    const history = await ShipmentStatus.getStatusHistory(shipment_id);

    res.json({
      shipment_id,
      history: history,
    });
  } catch (error) {
    console.error('Get shipment status history error:', error);
    res
      .status(500)
      .json({ message: 'خطأ في جلب سجل حالة الشحنة' });
  }
};

const getLatestStatus = async (req, res) => {
  try {
    const { shipment_id } = req.params;

    const latestStatus = await ShipmentStatus.getLatestStatus(shipment_id);

    if (!latestStatus) {
      return res
        .status(404)
        .json({ message: 'لا توجد تحديثات حالة لهذه الشحنة' });
    }

    res.json(latestStatus);
  } catch (error) {
    console.error('Get latest shipment status error:', error);
    res
      .status(500)
      .json({ message: 'خطأ في جلب آخر حالة للشحنة' });
  }
};

const getPODPhoto = async (req, res) => {
  try {
    const { shipment_id } = req.params;

    const photoPath = await ShipmentStatus.getPODPhoto(shipment_id);

    if (!photoPath) {
      return res
        .status(404)
        .json({ message: 'لا توجد صورة إثبات تسليم للشحنة' });
    }

    res.json({
      shipment_id,
      photo_path: photoPath,
    });
  } catch (error) {
    console.error('Get POD photo error:', error);
    res
      .status(500)
      .json({ message: 'خطأ في جلب صورة إثبات التسليم' });
  }
};

module.exports = {
  recordStatus,
  getStatusHistory,
  getLatestStatus,
  getPODPhoto,
};
