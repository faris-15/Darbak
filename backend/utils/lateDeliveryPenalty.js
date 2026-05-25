const MS_PER_DAY = 86400000;

const startOfLocalDay = (d) => {
  const x = d instanceof Date ? new Date(d.getTime()) : new Date(d);
  if (Number.isNaN(x.getTime())) return null;
  return new Date(x.getFullYear(), x.getMonth(), x.getDate());
};

/**
 * Whole calendar days from day `a` to day `b` (can be negative if b is before a).
 */
const calendarDaysFrom = (a, b) => {
  const sa = startOfLocalDay(a);
  const sb = startOfLocalDay(b);
  if (!sa || !sb) return 0;
  return Math.round((sb.getTime() - sa.getTime()) / MS_PER_DAY);
};

/**
 * Grace period after final deadline (default 5 full days with no penalty).
 * Day 6 after deadline: 5%; each further calendar day +5% until cap (default 25%).
 *
 * @param {Date|string} deadline - Final delivery date (الموعد النهائي)
 * @param {Date|string} asOfDate - "Today" for in-flight shipments, or actual delivery date when completing
 * @param {number} totalPrice - Accepted bid / shipment total used as penalty base
 * @param {{ graceDays?: number, dailyPercent?: number, capPercent?: number }} [options]
 * @returns {{ percent: number, amount: number, daysPastGrace: number }}
 */
const computeLatePenaltyFromDeadline = (deadline, asOfDate, totalPrice, options = {}) => {
  const graceDays = options.graceDays ?? 5;
  const dailyPercent = options.dailyPercent ?? 5;
  const capPercent = options.capPercent ?? 25;
  const price = Number(totalPrice);
  if (!Number.isFinite(price) || price <= 0) {
    return { percent: 0, amount: 0, daysPastGrace: 0 };
  }
  const daysSinceDeadline = calendarDaysFrom(deadline, asOfDate);
  if (daysSinceDeadline <= graceDays) {
    return { percent: 0, amount: 0, daysPastGrace: 0 };
  }
  const daysPastGrace = daysSinceDeadline - graceDays;
  const percent = Math.min(capPercent, daysPastGrace * dailyPercent);
  const amount = Number(((price * percent) / 100).toFixed(2));
  return { percent, amount, daysPastGrace };
};

const shipmentDeadline = (row) =>
  row?.final_delivery_date ?? row?.expected_delivery_date ?? null;

module.exports = {
  startOfLocalDay,
  calendarDaysFrom,
  computeLatePenaltyFromDeadline,
  shipmentDeadline,
};
