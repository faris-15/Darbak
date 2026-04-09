const express = require('express');
const router = express.Router();
const {
  recordStatus,
  getStatusHistory,
  getLatestStatus,
  getPODPhoto,
} = require('../controllers/shipmentStatusController');

// Record a new status update
router.post('/', recordStatus);

// Get complete timeline/history for a shipment
router.get('/:shipment_id/history', getStatusHistory);

// Get the current/latest status for a shipment
router.get('/:shipment_id/latest', getLatestStatus);

// Get the ePOD photo if available
router.get('/:shipment_id/pod-photo', getPODPhoto);

module.exports = router;
