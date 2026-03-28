const express = require('express');
const cors = require('cors');
const dotenv = require('dotenv');

dotenv.config();
const app = express();

app.use(cors());
app.use(express.json());

const authRoutes = require('./routes/authRoutes');
const shipmentRoutes = require('./routes/shipmentRoutes');
const bidRoutes = require('./routes/bidRoutes');
const conversationRoutes = require('./routes/conversationRoutes');
const payoutRoutes = require('./routes/payoutRoutes');

app.use('/api/auth', authRoutes);
app.use('/api/shipments', shipmentRoutes);
app.use('/api/bids', bidRoutes);
app.use('/api/conversations', conversationRoutes);
app.use('/api/payout', payoutRoutes);

app.get('/', (req, res) => {
  res.json({ message: 'Darbak backend is ready' });
});

const port = process.env.PORT || 5000;
app.listen(port, () => {
  console.log(`Server running on port ${port}`);
});
