const pool = require('../config/db');

const Shipment = {
  create: async ({
    shipperId,
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
    auctionEndTime,
  }) => {
    const [result] = await pool.execute(
      'INSERT INTO shipments (shipper_id, weight_kg, cargo_description, pickup_address, dropoff_address, pickup_lat, pickup_lng, dropoff_lat, dropoff_lng, base_price, expected_delivery_date, period, special_instructions, auction_duration_hours, auction_end_time, status) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [
        shipperId,
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
        auctionEndTime,
        'bidding',
      ]
    );
    return {
      id: result.insertId,
      shipper_id: shipperId,
      weight_kg: weightKg,
      cargo_description: cargoDescription,
      pickup_address: pickupAddress,
      dropoff_address: dropoffAddress,
      pickup_lat: pickupLat,
      pickup_lng: pickupLng,
      dropoff_lat: dropoffLat,
      dropoff_lng: dropoffLng,
      base_price: basePrice,
      expected_delivery_date: expectedDeliveryDate,
      period: period,
      special_instructions: specialInstructions,
      auction_duration_hours: auctionDurationHours,
      auction_end_time: auctionEndTime,
      status: 'bidding',
    };
  },

  findById: async (id) => {
    const [rows] = await pool.execute('SELECT * FROM shipments WHERE id = ?', [id]);
    return rows[0];
  },

  /** Count shipments for a shipper in given lifecycle statuses (e.g. active, open, bidding). */
  countByShipperInStatuses: async (shipperId, statuses) => {
    if (!statuses.length) return 0;
    const placeholders = statuses.map(() => '?').join(', ');
    const [rows] = await pool.execute(
      `SELECT COUNT(*) AS cnt FROM shipments WHERE shipper_id = ? AND status IN (${placeholders})`,
      [shipperId, ...statuses],
    );
    return Number(rows[0]?.cnt ?? 0);
  },

  list: async () => {
    const [rows] = await pool.execute('SELECT * FROM shipments ORDER BY created_at DESC');
    return rows;
  },

  listForShipper: async (shipperId) => {
    const [rows] = await pool.execute(
      'SELECT * FROM shipments WHERE shipper_id = ? ORDER BY created_at DESC',
      [shipperId]
    );
    return rows;
  },

  assignDriver: async (shipmentId, driverId) => {
    const [result] = await pool.execute('UPDATE shipments SET driver_id = ?, status = ? WHERE id = ?', [driverId, 'assigned', shipmentId]);
    return result.affectedRows > 0;
  },

  completeDelivery: async ({ shipmentId, bidAmount, actualDeliveryDate }) => {
    const shipment = await Shipment.findById(shipmentId);
    if (!shipment) throw new Error('Shipment not found');

    const expected = new Date(shipment.expected_delivery_date);
    const actual = new Date(actualDeliveryDate);
    let penaltyPercent = 0;

    // Compare only dates, ignore time
    const expectedDate = new Date(expected.getFullYear(), expected.getMonth(), expected.getDate());
    const actualDate = new Date(actual.getFullYear(), actual.getMonth(), actual.getDate());

    if (actualDate > expectedDate) {
      const diffTime = actualDate - expectedDate;
      const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24));
      penaltyPercent = Math.min(diffDays * 5, 100); // 5% لكل يوم تأخير، بحد أقصى 100%
    }

    const penaltyAmount = Number(((bidAmount * penaltyPercent) / 100).toFixed(2));
    const finalPrice = Number((Number(bidAmount) - penaltyAmount).toFixed(2));

    const [result] = await pool.execute(
      'UPDATE shipments SET actual_delivery_date = ?, final_price = ?, status = ? WHERE id = ?',
      [actualDeliveryDate, finalPrice, 'delivered', shipmentId]
    );

    return { success: result.affectedRows > 0, final_price: finalPrice, penalty_percent: penaltyPercent };
  },

  updateStatus: async (shipmentId, status) => {
    const [result] = await pool.execute(
      'UPDATE shipments SET status = ? WHERE id = ?',
      [status, shipmentId]
    );
    return result.affectedRows > 0;
  },

  listActiveByDriver: async (driverId) => {
    const [rows] = await pool.execute(
      `SELECT *
       FROM shipments
       WHERE driver_id = ?
         AND status IN ('assigned', 'at_pickup', 'en_route', 'at_dropoff')
       ORDER BY created_at DESC`,
      [driverId]
    );
    return rows;
  },

  listByDriverPriority: async (driverId) => {
    const [rows] = await pool.execute(
      `SELECT *,
        CASE
          WHEN status IN ('assigned', 'at_pickup', 'en_route', 'at_dropoff') THEN 1
          WHEN status IN ('delivered', 'cancelled') THEN 2
          ELSE 3
        END AS status_priority
       FROM shipments
       WHERE driver_id = ?
       ORDER BY
         status_priority ASC,
         CASE
           WHEN status IN ('assigned', 'at_pickup', 'en_route', 'at_dropoff') THEN created_at
           ELSE NULL
         END DESC,
         CASE
           WHEN status IN ('delivered', 'cancelled') THEN COALESCE(actual_delivery_date, created_at)
           ELSE NULL
         END DESC,
         created_at DESC`,
      [driverId]
    );
    return rows;
  },

  setDeliveryMetadata: async (shipmentId, { actualDeliveryDate, podPhotoPath }) => {
    const [result] = await pool.execute(
      'UPDATE shipments SET actual_delivery_date = ? WHERE id = ?',
      [actualDeliveryDate, shipmentId]
    );
    return result.affectedRows > 0;
  },

  getDriverStats: async (driverId) => {
    const [rows] = await pool.execute(
      'SELECT COUNT(*) as completed_trips, SUM(final_price) as total_earnings FROM shipments WHERE driver_id = ? AND status = ?',
      [driverId, 'delivered']
    );
    return {
      completed_trips: rows[0]?.completed_trips || 0,
      total_earnings: rows[0]?.total_earnings || 0,
    };
  },

  getShipperStats: async (shipperId) => {
    const [rows] = await pool.execute(
      'SELECT \
         COUNT(*) as total_shipments, \
         SUM(CASE WHEN status = \'delivered\' THEN 1 ELSE 0 END) as delivered_shipments, \
         SUM(CASE WHEN status != \'delivered\' AND status != \'cancelled\' THEN 1 ELSE 0 END) as active_shipments \
       FROM shipments \
       WHERE shipper_id = ?',
      [shipperId]
    );
    return {
      total_shipments: rows[0]?.total_shipments || 0,
      delivered_shipments: rows[0]?.delivered_shipments || 0,
      active_shipments: rows[0]?.active_shipments || 0,
    };
  },
};

module.exports = Shipment;
