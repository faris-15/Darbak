const express = require('express');

const router = express.Router();

const AdminController = require('../controllers/adminController');
const { requireAuth, requireAdmin } = require('../middleware/authMiddleware');

router.use(requireAuth, requireAdmin);

// مسارات محددة النص يجب أن تسبق :param لتجنب التقاط "browse" كمعرف

router.get('/stats', AdminController.getStats);

router.get('/overview-charts', AdminController.overviewCharts);

router.get('/users/browse', AdminController.browseUsers);

router.get('/shipments/browse', AdminController.browseShipments);

router.get('/shipments/:id/detail', AdminController.getShipmentDetail);

router.get('/users/:id/detail', AdminController.getUserDetail);

router.patch('/users/:id/active', AdminController.patchUserActive);

router.post('/users', AdminController.createUser);

router.patch('/users/:id', AdminController.patchUser);

router.get('/users', AdminController.getUsers);

router.get('/shipments', AdminController.getShipments);

router.get('/pending-users', AdminController.getPendingUsers);

router.get('/activity-feed', AdminController.activityFeed);

router.get('/notifications', AdminController.notificationsList);

router.post('/notifications/read', AdminController.notificationsRead);

router.get('/disputes', AdminController.listDisputes);

router.post('/disputes/resolve', AdminController.resolveDisputeStub);

router.get('/get-signed-url', AdminController.getSignedUrl);

router.get('/documents/preview', AdminController.previewDocumentByQuery);

router.get('/documents/:id/preview', AdminController.previewDocumentById);

router.post('/documents/:docId/verify', AdminController.verifyDocument);

router.post('/operating-cards/:cardId/verify', AdminController.verifyOperatingCard);

router.post('/users/:id/verify', AdminController.verifyUser);

router.get('/price-floors', AdminController.getPriceFloors);

router.post('/price-floors', AdminController.createPriceFloor);

router.delete('/price-floors/:id', AdminController.deletePriceFloor);

router.get('/export-report', AdminController.exportReport);



module.exports = router;
