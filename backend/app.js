const express = require('express');
const cors = require('cors');
const dotenv = require('dotenv');
const path = require('path');

dotenv.config();
const app = express();

app.use(cors());
app.use(express.json());
app.use('/uploads', express.static(path.join(__dirname, 'uploads')));

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

app.get('/', (req, res) => {
  res.json({ message: 'Darbak backend is ready' });
});

const port = process.env.PORT || 5000;
app.listen(port, () => {
  console.log(`Server running on port ${port}`);
});
