const pool = require('../config/db');

const Shipment = {
  create: async ({ shipperId, weightKg, cargoDescription, pickupAddress, dropoffAddress, basePrice, expectedDeliveryDate }) => {
    const [result] = await pool.execute(
      'INSERT INTO shipments (shipper_id, weight_kg, cargo_description, pickup_address, dropoff_address, base_price, expected_delivery_date, status) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
      [shipperId, weightKg, cargoDescription, pickupAddress, dropoffAddress, basePrice, expectedDeliveryDate, 'bidding']
    );
    return {
      id: result.insertId,
      shipper_id: shipperId,
      weight_kg: weightKg,
      cargo_description: cargoDescription,
      pickup_address: pickupAddress,
      dropoff_address: dropoffAddress,
      base_price: basePrice,
      expected_delivery_date: expectedDeliveryDate,
      status: 'bidding',
    };
  },

  findById: async (id) => {
    const [rows] = await pool.execute('SELECT * FROM shipments WHERE id = ?', [id]);
    return rows[0];
  },

  list: async () => {
    const [rows] = await pool.execute('SELECT * FROM shipments ORDER BY created_at DESC');
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

    if (actual > expected) {
      const msPerDay = 24 * 60 * 60 * 1000;
      const daysLate = Math.ceil((actual - expected) / msPerDay);
      penaltyPercent = Math.min(daysLate * 5, 25);
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
};

module.exports = Shipment;
