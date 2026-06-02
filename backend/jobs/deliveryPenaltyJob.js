const pool = require('../config/db');
const { sendPushToUser } = require('../utils/fcmPush');
const { triggerNotification } = require('../controllers/notificationController');
const {
  computeLatePenaltyFromDeadline,
  shipmentDeadline,
} = require('../utils/lateDeliveryPenalty');

const ACTIVE_STATUSES = ['assigned', 'at_pickup', 'en_route', 'at_dropoff'];

const acceptedBidAmountSql = `(
          SELECT b.bid_amount
          FROM bids b
          WHERE b.shipment_id = s.id
            AND b.bid_status = 'accepted'
          ORDER BY b.created_at DESC
          LIMIT 1
        )`;

/**
 * Daily sweep: update penalty_amount for driver-assigned, undelivered shipments
 * past the deadline (0-day grace). Sends FCM + in-app notification once when penalty first becomes > 0.
 */
const runDeliveryPenaltySweep = async () => {
  const placeholders = ACTIVE_STATUSES.map(() => '?').join(', ');
  const [rows] = await pool.execute(
    `SELECT s.id, s.driver_id, s.status, s.penalty_amount, s.late_penalty_push_sent,
            s.final_delivery_date, s.expected_delivery_date,
            ${acceptedBidAmountSql} AS accepted_bid_amount
     FROM shipments s
     WHERE s.driver_id IS NOT NULL
       AND s.actual_delivery_date IS NULL
       AND s.status IN (${placeholders})`,
    [...ACTIVE_STATUSES],
  );

  const now = new Date();
  let updated = 0;
  let notified = 0;

  for (const row of rows) {
    const deadline = shipmentDeadline(row);
    const bidAmount = Number(row.accepted_bid_amount);
    if (!deadline || !Number.isFinite(bidAmount) || bidAmount <= 0) continue;

    const { percent, amount } = computeLatePenaltyFromDeadline(deadline, now, bidAmount);
    console.log(`Checking Shipment #${row.id}: Deadline=${deadline.toISOString()}, Penalty=${amount}, PrevSent=${row.late_penalty_push_sent}`);
    const prevSent = Number(row.late_penalty_push_sent || 0) === 1;

    const prevAmount = Number(row.penalty_amount || 0);
    if (prevAmount !== amount) {
      await pool.execute('UPDATE shipments SET penalty_amount = ? WHERE id = ?', [amount, row.id]);
    }
    updated += 1;

    const shouldNotifyFirstPenalty = amount > 0 && !prevSent;
    if (shouldNotifyFirstPenalty) {
      const driverId = Number(row.driver_id);
      const title = 'تنبيه تأخير التوصيل';
      const body = `تم تطبيق خصم تأخير ${percent}% على شحنة #${row.id}. سيتم خصم ${amount} ريال من مستحقاتك.`;
      await sendPushToUser(driverId, {
        title,
        body,
        data: { type: 'late_delivery_penalty', shipment_id: String(row.id), percent: String(percent) },
      });
      await triggerNotification(driverId, title, body, { shipment_id: row.id });
      await pool.execute('UPDATE shipments SET late_penalty_push_sent = 1 WHERE id = ?', [row.id]);
      notified += 1;
    }
  }

  console.log(`[deliveryPenaltyJob] updated=${updated} first-penalty-notifications=${notified}`);
  return { updated, notified };
};

module.exports = { runDeliveryPenaltySweep };
