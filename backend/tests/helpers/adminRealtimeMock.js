'use strict';

const ADMIN_DASHBOARD_ROOM = 'admin:dashboard';

const emitAdminDashboard = jest.fn();
const emitAdminDashboardIo = jest.fn();

module.exports = {
  ADMIN_DASHBOARD_ROOM,
  emitAdminDashboard,
  emitAdminDashboardIo,
};
