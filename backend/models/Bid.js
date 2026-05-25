const pool = require('../config/db');
const Rating = require('./Rating');

const Bid = {
  create: async ({ shipmentId, driverId, bidAmount, estimatedDays }) => {
    const [result] = await pool.execute(
      'INSERT INTO bids (shipment_id, driver_id, bid_amount, estimated_days) VALUES (?, ?, ?, ?)',
      [shipmentId, driverId, bidAmount, estimatedDays]
    );
    return { id: result.insertId, shipmentId, driverId, bid_amount: bidAmount, estimated_days: estimatedDays };
  },

  findByShipment: async (shipmentId) => {
    const [rows] = await pool.execute('SELECT * FROM bids WHERE shipment_id = ? ORDER BY bid_amount ASC', [shipmentId]);
    return rows;
  },

  findById: async (id) => {
    const [rows] = await pool.execute('SELECT * FROM bids WHERE id = ?', [id]);
    return rows[0];
  },

  /**
   * Reject pending bids on shipments whose auction window has ended (still open for assignment).
   * Keeps one-bid-room rules accurate and matches product expectation that offers end with the auction.
   */
  expirePendingBidsPastAuctionEnd: async () => {
    const [result] = await pool.execute(
      `UPDATE bids b
       INNER JOIN shipments s ON s.id = b.shipment_id
       SET b.bid_status = 'rejected'
       WHERE b.bid_status = 'pending'
         AND s.status IN ('pending', 'bidding')
         AND s.auction_end_time IS NOT NULL
         AND s.auction_end_time <= NOW()`
    );
    return result.affectedRows ?? 0;
  },

  findActiveParticipationForDriver: async (driverId, options = {}) => {
    const excludeShipmentId = options.excludeShipmentId;
    let sql = `SELECT b.id AS bid_id, b.shipment_id, b.bid_amount, b.estimated_days,
              s.pickup_address, s.dropoff_address
       FROM bids b
       INNER JOIN shipments s ON s.id = b.shipment_id
       WHERE b.driver_id = ?
         AND b.bid_status = 'pending'
         AND s.status IN ('bidding', 'pending')
         AND (s.auction_end_time IS NULL OR s.auction_end_time > NOW())`;
    const params = [driverId];
    if (excludeShipmentId != null && excludeShipmentId !== '') {
      sql += ' AND b.shipment_id <> ?';
      params.push(excludeShipmentId);
    }
    sql += ' LIMIT 1';
    const [rows] = await pool.execute(sql, params);
    return rows[0] || null;
  },

  findActiveParticipationOnOtherShipment: async (driverId, excludeShipmentId) =>
    Bid.findActiveParticipationForDriver(driverId, { excludeShipmentId }),

  setStatus: async (id, status) => {
    const [result] = await pool.execute('UPDATE bids SET bid_status = ? WHERE id = ?', [status, id]);
    return result.affectedRows > 0;
  },

  rejectOtherBidsForShipment: async (shipmentId, acceptedBidId) => {
    const [result] = await pool.execute('UPDATE bids SET bid_status = ? WHERE shipment_id = ? AND id != ?', ['rejected', shipmentId, acceptedBidId]);
    return result.affectedRows;
  },

  findByShipmentWithDriver: async (shipmentId) => {
    const ratingColumns = await Rating.getColumnMap();
    const [rows] = await pool.execute(
      `SELECT 
        b.id, 
        b.shipment_id, 
        b.driver_id, 
        b.bid_amount, 
        b.estimated_days, 
        b.bid_status,
        u.id as user_id,
        u.full_name as driver_name,
        u.license_no,
        u.phone,
        (
          SELECT COALESCE(AVG(${ratingColumns.starsColumn}), 0)
          FROM ratings
          WHERE ${ratingColumns.ratedColumn} = b.driver_id
            AND ${ratingColumns.starsColumn} BETWEEN 1 AND 5
        ) as driver_rating,
        (
          SELECT COUNT(*)
          FROM ratings
          WHERE ${ratingColumns.ratedColumn} = b.driver_id
            AND ${ratingColumns.starsColumn} BETWEEN 1 AND 5
        ) as rating_count
      FROM bids b
      LEFT JOIN users u ON b.driver_id = u.id
      WHERE b.shipment_id = ?
      ORDER BY b.bid_amount ASC`,
      [shipmentId]
    );
    return rows;
  },

  acceptBid: async (bidId, shipmentId) => {
    const [result] = await pool.execute(
      'UPDATE bids SET bid_status = ? WHERE id = ?',
      ['accepted', bidId]
    );
    return result.affectedRows > 0;
  },
};

module.exports = Bid;