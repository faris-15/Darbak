const pool = require('../config/db');

const BiddingRoom = {
  create: async (shipmentId) => {
    const [result] = await pool.execute('INSERT INTO bidding_rooms (shipment_id) VALUES (?)', [shipmentId]);
    return {
      id: result.insertId,
      shipment_id: shipmentId,
      active_driver_id: null,
      lowest_bidder_id: null,
      lowest_bid_amount: null,
      room_status: 'open',
    };
  },

  findByShipmentId: async (shipmentId) => {
    const [rows] = await pool.execute('SELECT * FROM bidding_rooms WHERE shipment_id = ?', [shipmentId]);
    return rows[0];
  },

  findById: async (id) => {
    const [rows] = await pool.execute('SELECT * FROM bidding_rooms WHERE id = ?', [id]);
    return rows[0];
  },

  enterRoom: async (shipmentId, driverId) => {
    // Check if driver is already in another room (exclusive participation)
    const [activeRooms] = await pool.execute(
      'SELECT * FROM bidding_rooms WHERE active_driver_id = ? AND room_status IN ("open", "locked")',
      [driverId]
    );

    if (activeRooms.length > 0) {
      throw new Error('Driver already active in another room');
    }

    // Enter the room
    const [result] = await pool.execute(
      'UPDATE bidding_rooms SET active_driver_id = ? WHERE shipment_id = ?',
      [driverId, shipmentId]
    );

    return result.affectedRows > 0;
  },

  exitRoom: async (shipmentId, driverId) => {
    const room = await BiddingRoom.findByShipmentId(shipmentId);
    if (!room) throw new Error('Room not found');

    // If exiting driver is the lowest bidder, lock them in
    if (room.lowest_bidder_id == driverId) {
      // Lock the driver (they can't leave if they're lowest)
      throw new Error('You are the lowest bidder and cannot exit the room');
    }

    // Remove driver from room
    const [result] = await pool.execute(
      'UPDATE bidding_rooms SET active_driver_id = NULL WHERE shipment_id = ?',
      [shipmentId]
    );

    return result.affectedRows > 0;
  },

  updateLowestBid: async (shipmentId, driverId, bidAmount) => {
    const [result] = await pool.execute(
      'UPDATE bidding_rooms SET lowest_bidder_id = ?, lowest_bid_amount = ? WHERE shipment_id = ?',
      [driverId, bidAmount, shipmentId]
    );
    return result.affectedRows > 0;
  },

  closeRoom: async (shipmentId) => {
    const [result] = await pool.execute(
      'UPDATE bidding_rooms SET room_status = "closed" WHERE shipment_id = ?',
      [shipmentId]
    );
    return result.affectedRows > 0;
  },

  lockRoom: async (shipmentId) => {
    const [result] = await pool.execute(
      'UPDATE bidding_rooms SET room_status = "locked" WHERE shipment_id = ?',
      [shipmentId]
    );
    return result.affectedRows > 0;
  },

  getActiveRoomsForDriver: async (driverId) => {
    const [rows] = await pool.execute(
      'SELECT * FROM bidding_rooms WHERE active_driver_id = ? AND room_status IN ("open", "locked")',
      [driverId]
    );
    return rows;
  },
};

module.exports = BiddingRoom;
