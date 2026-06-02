/**
 * Builds a minimal in-process Express app wired with the production routes.
 * Importantly we do NOT require `../../app.js` directly because that file
 * starts an HTTP listener and a cron job. Instead we re-mount the same
 * routes so each test gets a fresh app instance.
 *
 * Usage:
 *
 *   const { buildTestApp } = require('./helpers/testApp');
 *   const app = buildTestApp();
 *   await request(app).post('/api/auth/login').send({ ... });
 */
'use strict';

const express = require('express');
const cors = require('cors');

const buildTestApp = ({ routes = 'all', io = null } = {}) => {
  const app = express();
  app.use(cors());
  app.use(express.json());

  if (io) app.set('io', io);

  const wantsAll = routes === 'all';
  const wants = (key) => wantsAll || (Array.isArray(routes) && routes.includes(key));

  if (wants('auth')) app.use('/api/auth', require('../../routes/authRoutes'));
  if (wants('shipments')) app.use('/api/shipments', require('../../routes/shipmentRoutes'));
  if (wants('bids')) app.use('/api/bids', require('../../routes/bidRoutes'));
  if (wants('biddingRooms'))
    app.use('/api/bidding-rooms', require('../../routes/biddingRoomRoutes'));
  if (wants('conversations'))
    app.use('/api/conversations', require('../../routes/conversationRoutes'));
  if (wants('payout')) app.use('/api/payout', require('../../routes/payoutRoutes'));
  if (wants('trucks')) app.use('/api/trucks', require('../../routes/truckRoutes'));
  if (wants('ratings')) app.use('/api/ratings', require('../../routes/ratingRoutes'));
  if (wants('notifications'))
    app.use('/api/notifications', require('../../routes/notificationRoutes'));
  if (wants('shipmentStatus'))
    app.use('/api/shipment-status', require('../../routes/shipmentStatusRoutes'));
  if (wants('chat')) app.use('/api/chat', require('../../routes/chatRoutes'));
  if (wants('admin')) app.use('/api/admin', require('../../routes/adminRoutes'));
  if (wants('profile')) app.use('/api/profile', require('../../routes/profileRoutes'));
  if (wants('users')) app.use('/api/users', require('../../routes/userRoutes'));
  if (wants('operatingCard'))
    app.use('/api/operating-card', require('../../routes/operatingCardRoutes'));

  app.get('/healthz', (_req, res) => res.json({ ok: true }));

  return app;
};

module.exports = { buildTestApp };
