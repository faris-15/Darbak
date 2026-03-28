const Shipment = require('../models/Shipment');

const createShipment = async (req, res) => {
  try {
    const { shipperId, origin, destination, freightType, weight, value, edt } = req.body;
    const shipment = await Shipment.create({ shipperId, origin, destination, freightType, weight, value, edt });
    res.status(201).json(shipment);
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'خطأ في إنشاء الشحنة' });
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

module.exports = { createShipment, listShipments, getShipment };