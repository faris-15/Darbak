const express = require('express');
const router = express.Router();
const AdminController = require('../controllers/adminController');
const { requireAdmin } = require('../middleware/authMiddleware');

router.use(requireAdmin);

router.get('/stats', AdminController.getStats);
router.get('/activity-feed', AdminController.getActivityFeed);
router.get('/notifications', AdminController.getNotifications);
router.post('/notifications/read', AdminController.markNotificationsRead);

router.get('/users/browse', AdminController.browseUsers);
router.get('/users/:id/detail', AdminController.getUserDetail);
router.patch('/users/:id/active', AdminController.setUserActive);
router.post('/users/:id/verify', AdminController.verifyUser);
router.get('/users', AdminController.getUsers);

router.get('/shipments/browse', AdminController.browseShipments);
router.get('/shipments', AdminController.getShipments);

router.get('/pending-users', AdminController.getPendingUsers);
router.get('/documents/preview', AdminController.streamDocumentPreview);
router.get('/documents/:docId/preview', AdminController.streamDocumentPreviewById);
router.post('/documents/:docId/verify', AdminController.verifyDocument);
router.get('/get-signed-url', AdminController.getSignedUrl);

router.get('/disputes', AdminController.listDisputes);
/** Body: { transactionId, status } — توافق مع الواجهة القديمة */
router.post('/disputes/resolve', AdminController.resolveDispute);
router.post('/disputes/:id/resolve', AdminController.resolveDispute);

router.get('/price-floors', AdminController.getPriceFloors);
router.post('/price-floors', AdminController.createPriceFloor);
router.delete('/price-floors/:id', AdminController.deletePriceFloor);
router.get('/export-report', AdminController.exportReport);

module.exports = router;
