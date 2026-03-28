const Bid = require('../models/Bid');

const createBid = async (req, res) => {
  try {
    const { shipmentId, driverId, amount, etaDays } = req.body;
    const bid = await Bid.create({ shipmentId, driverId, amount, etaDays });
    res.status(201).json(bid);
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