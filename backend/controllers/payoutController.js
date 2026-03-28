const { calculatePayout } = require('../services/payoutService');

const computePayout = (req, res) => {
  try {
    const { totalAmount, edt, actualDeliveryDate } = req.body;
    if (!totalAmount || !edt || !actualDeliveryDate) {
      return res.status(400).json({ message: 'يرجى تقديم totalAmount و edt و actualDeliveryDate' });
    }

    const result = calculatePayout({
      totalAmount: Number(totalAmount),
      edt,
      actualDeliveryDate,
    });

    return res.json(result);
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'خطأ في حساب الإتمنة' });
  }
};

module.exports = { computePayout };