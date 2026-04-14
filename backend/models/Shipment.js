const pool = require('../config/db');

const Shipment = {
  create: async ({ shipperId, weightKg, cargoDescription, pickupAddress, dropoffAddress, basePrice, expectedDeliveryDate, period }) => {
    const [result] = await pool.execute(
      'INSERT INTO shipments (shipper_id, weight_kg, cargo_description, pickup_address, dropoff_address, base_price, expected_delivery_date, period, status) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [shipperId, weightKg, cargoDescription, pickupAddress, dropoffAddress, basePrice, expectedDeliveryDate, period, 'bidding']
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
      period: period,
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

    // Compare only dates, ignore time
    const expectedDate = new Date(expected.getFullYear(), expected.getMonth(), expected.getDate());
    const actualDate = new Date(actual.getFullYear(), actual.getMonth(), actual.getDate());

    if (actualDate > expectedDate) {
      penaltyPercent = 25;
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
