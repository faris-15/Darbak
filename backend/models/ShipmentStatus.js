const pool = require('../config/db');

const ShipmentStatus = {
  // Record a status change in the shipment timeline
  recordStatus: async ({
    shipment_id,
    status,
    location_lat,
    location_lng,
    photo_path,
  }) => {
    const [result] = await pool.execute(
      'INSERT INTO shipment_status_history (shipment_id, status, location_lat, location_lng, photo_path) VALUES (?, ?, ?, ?, ?)',
      [shipment_id, status, location_lat, location_lng, photo_path],
    );
    return {
      id: result.insertId,
      shipment_id: shipment_id,
      status: status,
      location_lat: location_lat,
      location_lng: location_lng,
      photo_path: photo_path,
      updated_at: new Date(),
    };
  },

  // Get all status updates for a shipment (timeline)
  getStatusHistory: async (shipment_id) => {
    const [rows] = await pool.execute(
      'SELECT * FROM shipment_status_history WHERE shipment_id = ? ORDER BY updated_at ASC',
      [shipment_id],
    );
    return rows;
  },

  // Get the latest status for a shipment
  getLatestStatus: async (shipment_id) => {
    const [rows] = await pool.execute(
      'SELECT * FROM shipment_status_history WHERE shipment_id = ? ORDER BY updated_at DESC LIMIT 1',
      [shipment_id],
    );
    return rows[0];
  },

  // Get ePOD photo path if delivery was documented
  getPODPhoto: async (shipment_id) => {
    const [rows] = await pool.execute(
      'SELECT photo_path FROM shipment_status_history WHERE shipment_id = ? AND photo_path IS NOT NULL ORDER BY updated_at DESC LIMIT 1',
      [shipment_id],
    );
    return rows[0]?.photo_path || null;
  },

  // Update location for current status
  updateLocation: async (shipment_id, location_lat, location_lng) => {
    const [result] = await pool.execute(
      'UPDATE shipment_status_history SET location_lat = ?, location_lng = ? WHERE shipment_id = ? ORDER BY updated_at DESC LIMIT 1',
      [location_lat, location_lng, shipment_id],
    );
    return result.affectedRows > 0;
  },
};

module.exports = ShipmentStatus;
