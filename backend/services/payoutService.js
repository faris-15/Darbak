function calculatePayout({ totalAmount, edt, actualDeliveryDate }) {
  const expected = new Date(edt);
  const actual = new Date(actualDeliveryDate);
  let deduction = 0;

  if (actual > expected) {
    const diffMs = actual.getTime() - expected.getTime();
    const delayDays = Math.ceil(diffMs / (1000 * 60 * 60 * 24));
    deduction = Math.min(delayDays * 0.05, 0.25); // 5% per delayed day up to 25%
  }

  const finalAmount = totalAmount * (1 - deduction);
  return {
    totalAmount,
    delayDays: Math.max(0, Math.ceil((new Date(actualDeliveryDate).getTime() - new Date(edt).getTime()) / (1000 * 60 * 60 * 24))),
    deductionRate: deduction,
    finalAmount: Number(finalAmount.toFixed(2)),
  };
}

module.exports = {
  calculatePayout,
};