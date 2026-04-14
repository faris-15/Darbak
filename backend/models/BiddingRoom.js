const pool = require('../config/db');

const BiddingRoom = {
  create: async (shipmentId) => {
    try {
      const [result] = await pool.execute('INSERT INTO bids (shipment_id) VALUES (?)', [shipmentId]);
      return {
        id: result.insertId,
        shipment_id: shipmentId,
        active_driver_id: null,
        lowest_bidder_id: null,
        lowest_bid_amount: null,
        room_status: 'open',
      };
    } catch (error) {
      console.error('[BiddingRoom.create] Database error:', error.message, error.code);
      throw error;
    }
  },

  findByShipmentId: async (shipmentId) => {
    try {
      const [rows] = await pool.execute('SELECT * FROM bids WHERE shipment_id = ?', [shipmentId]);
      return rows[0];
    } catch (error) {
      console.error('[BiddingRoom.findByShipmentId] Database error:', error.message, error.code);
      throw error;
    }
  },

  findById: async (id) => {
    try {
      const [rows] = await pool.execute('SELECT * FROM bids WHERE id = ?', [id]);
      return rows[0];
    } catch (error) {
      console.error('[BiddingRoom.findById] Database error:', error.message, error.code);
      throw error;
    }
  },

  enterRoom: async (shipmentId, driverId) => {
    try {
      // Check if driver is already in another room (exclusive participation)
      const [activeRooms] = await pool.execute(
        'SELECT * FROM bids WHERE driver_id = ? AND (bid_status = "pending" OR bid_status = "locked")',
        [driverId]
      );

      if (activeRooms.length > 0) {
        throw new Error('Driver already active in another bidding');
      }

      // Enter the room by creating/updating driver's bid entry
      const [result] = await pool.execute(
        'UPDATE bids SET driver_id = ? WHERE shipment_id = ? AND driver_id IS NULL LIMIT 1',
        [driverId, shipmentId]
      );

      return result.affectedRows > 0;
    } catch (error) {
      console.error('[BiddingRoom.enterRoom] Database error:', error.message, error.code);
      throw error;
    }
  },

  exitRoom: async (shipmentId, driverId) => {
    try {
      const room = await BiddingRoom.findByShipmentId(shipmentId);
      if (!room) throw new Error('Room not found');

      // If exiting driver is the lowest bidder, lock them in
      if (room.lowest_bidder_id == driverId) {
        throw new Error('You are the lowest bidder and cannot exit the room');
      }

      // Remove driver from room
      const [result] = await pool.execute(
        'UPDATE bids SET driver_id = NULL WHERE shipment_id = ? AND driver_id = ?',
        [shipmentId, driverId]
      );

      return result.affectedRows > 0;
    } catch (error) {
      console.error('[BiddingRoom.exitRoom] Database error:', error.message, error.code);
      throw error;
    }
  },

  updateLowestBid: async (shipmentId, driverId, bidAmount) => {
    try {
      const [result] = await pool.execute(
        'UPDATE bids SET lowest_bidder_id = ?, lowest_bid_amount = ? WHERE shipment_id = ?',
        [driverId, bidAmount, shipmentId]
      );
      return result.affectedRows > 0;
    } catch (error) {
      console.error('[BiddingRoom.updateLowestBid] Database error:', error.message, error.code);
      throw error;
    }
  },

  closeRoom: async (shipmentId) => {
    try {
      const [result] = await pool.execute(
        'UPDATE bids SET bid_status = "closed" WHERE shipment_id = ?',
        [shipmentId]
      );
      return result.affectedRows > 0;
    } catch (error) {
      console.error('[BiddingRoom.closeRoom] Database error:', error.message, error.code);
      throw error;
    }
  },

  lockRoom: async (shipmentId) => {
    try {
      const [result] = await pool.execute(
        'UPDATE bids SET bid_status = "locked" WHERE shipment_id = ?',
        [shipmentId]
      );
      return result.affectedRows > 0;
    } catch (error) {
      console.error('[BiddingRoom.lockRoom] Database error:', error.message, error.code);
      throw error;
    }
  },

  getActiveRoomsForDriver: async (driverId) => {
    try {
      const [rows] = await pool.execute(
        'SELECT * FROM bids WHERE driver_id = ? AND bid_status IN ("pending", "locked")',
        [driverId]
      );
      return rows;
    } catch (error) {
      console.error('[BiddingRoom.getActiveRoomsForDriver] Database error:', error.message, error.code);
      throw error;
    }
  },
};

module.exports = BiddingRoom;
