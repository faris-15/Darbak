const express = require('express');
const cors = require('cors');
const dotenv = require('dotenv');
const path = require('path');
const http = require('http');
const { Server } = require('socket.io');

dotenv.config({ path: path.join(__dirname, '.env') });
const app = express();
const server = http.createServer(app);
const io = new Server(server, {
  cors: {
    origin: '*',
    methods: ['GET', 'POST'],
  },
});
app.set('io', io);

app.use(cors());
app.use(express.json());
app.use('/uploads', express.static(path.join(__dirname, 'uploads')));
app.use('/assets', express.static(path.join(__dirname, '../assets')));

const authRoutes = require('./routes/authRoutes');
const shipmentRoutes = require('./routes/shipmentRoutes');
const bidRoutes = require('./routes/bidRoutes');
const conversationRoutes = require('./routes/conversationRoutes');
const payoutRoutes = require('./routes/payoutRoutes');
const biddingRoomRoutes = require('./routes/biddingRoomRoutes');
const truckRoutes = require('./routes/truckRoutes');
const ratingRoutes = require('./routes/ratingRoutes');
const notificationRoutes = require('./routes/notificationRoutes');
const shipmentStatusRoutes = require('./routes/shipmentStatusRoutes');
const chatRoutes = require('./routes/chatRoutes');
const adminRoutes = require('./routes/adminRoutes');
const profileRoutes = require('./routes/profileRoutes');
const userRoutes = require('./routes/userRoutes');
const operatingCardRoutes = require('./routes/operatingCardRoutes');
const configureChatSocket = require('./socket/chatSocket');
const cron = require('node-cron');
const { runDeliveryPenaltySweep } = require('./jobs/deliveryPenaltyJob');

configureChatSocket(io);

app.use('/api/auth', authRoutes);
app.use('/api/shipments', shipmentRoutes);
app.use('/api/bids', bidRoutes);
app.use('/api/bidding-rooms', biddingRoomRoutes);
app.use('/api/conversations', conversationRoutes);
app.use('/api/payout', payoutRoutes);
app.use('/api/trucks', truckRoutes);
app.use('/api/ratings', ratingRoutes);
app.use('/api/notifications', notificationRoutes);
app.use('/api/shipment-status', shipmentStatusRoutes);
app.use('/api/chat', chatRoutes);
app.use('/api/admin', adminRoutes);
app.use('/api/profile', profileRoutes);
app.use('/api/users', userRoutes);
app.use('/api/operating-card', operatingCardRoutes);

// Admin SPA: express.static alone often misses GET /admin (no trailing slash) → blank / 404.
const adminPortalDir = path.join(__dirname, 'admin_portal');
const sendAdminIndex = (_req, res) => {
  res.sendFile(path.join(adminPortalDir, 'index.html'));
};
app.get('/admin', sendAdminIndex);
app.get('/admin/', sendAdminIndex);
app.use('/admin', express.static(adminPortalDir));

app.get('/', (req, res) => {
  res.json({ message: 'Darbak backend is ready' });
});

const { ensureTruckClassificationSchema } = require('./utils/truckClassificationSchema');
const { ensureShipmentTruckSchema } = require('./utils/shipmentTruckSchema');

const port = process.env.PORT || 5000;
server.listen(port, () => {
  console.log(`Server running on port ${port}`);
  ensureTruckClassificationSchema().catch((err) =>
    console.error('[TruckClassificationSchema] startup ensure failed:', err.message)
  );
  ensureShipmentTruckSchema().catch((err) =>
    console.error('[ShipmentTruckSchema] startup ensure failed:', err.message)
  );
  if (process.env.DISABLE_DELIVERY_PENALTY_CRON !== '1') {
    cron.schedule('0 2 * * *', () => {
      runDeliveryPenaltySweep().catch((err) => console.error('[deliveryPenaltyCron]', err));
    });
    console.log('[deliveryPenaltyCron] scheduled daily at 02:00 (server local time)');
  }
});
