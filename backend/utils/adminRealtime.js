/** Socket.IO room for logged-in admin clients (see socket/chatSocket.js). */
const ADMIN_DASHBOARD_ROOM = 'admin:dashboard';

function emitAdminDashboard(req, reason, meta = {}) {
  try {
    const io = req.app?.get?.('io');
    if (!io) return;
    emitAdminDashboardIo(io, reason, meta);
  } catch (e) {
    console.warn('[adminRealtime] emit failed:', e.message);
  }
}

function emitAdminDashboardIo(io, reason, meta = {}) {
  if (!io) return;
  try {
    io.to(ADMIN_DASHBOARD_ROOM).emit('admin:refresh', {
      reason: String(reason || 'update'),
      meta: meta && typeof meta === 'object' ? meta : {},
      at: new Date().toISOString(),
    });
  } catch (e) {
    console.warn('[adminRealtime] emit Io failed:', e.message);
  }
}

module.exports = { ADMIN_DASHBOARD_ROOM, emitAdminDashboard, emitAdminDashboardIo };
