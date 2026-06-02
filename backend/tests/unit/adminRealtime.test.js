/**
 * Unit tests for utils/adminRealtime. setup.js mocks the module globally —
 * we use jest.requireActual to test the real implementation.
 */
'use strict';

const adminRealtime = jest.requireActual('../../utils/adminRealtime');
const { emitAdminDashboard, emitAdminDashboardIo, ADMIN_DASHBOARD_ROOM } =
  adminRealtime;

describe('adminRealtime.emitAdminDashboardIo', () => {
  test('emits to admin dashboard room with reason + meta', () => {
    const emit = jest.fn();
    const io = { to: jest.fn().mockReturnValue({ emit }) };
    emitAdminDashboardIo(io, 'shipment.created', { shipmentId: 5 });
    expect(io.to).toHaveBeenCalledWith(ADMIN_DASHBOARD_ROOM);
    expect(emit).toHaveBeenCalledWith(
      'admin:refresh',
      expect.objectContaining({
        reason: 'shipment.created',
        meta: { shipmentId: 5 },
      }),
    );
  });

  test('coerces missing reason to "update" and bad meta to {}', () => {
    const emit = jest.fn();
    const io = { to: jest.fn().mockReturnValue({ emit }) };
    emitAdminDashboardIo(io, null, 'not-an-object');
    expect(emit).toHaveBeenCalledWith(
      'admin:refresh',
      expect.objectContaining({ reason: 'update', meta: {} }),
    );
  });

  test('no-ops when io is falsy', () => {
    expect(() => emitAdminDashboardIo(null, 'x')).not.toThrow();
  });

  test('swallows underlying io errors', () => {
    const io = {
      to: () => {
        throw new Error('socket down');
      },
    };
    expect(() => emitAdminDashboardIo(io, 'x')).not.toThrow();
  });
});

describe('adminRealtime.emitAdminDashboard (req-based)', () => {
  test('uses io attached to the express app', () => {
    const emit = jest.fn();
    const io = { to: jest.fn().mockReturnValue({ emit }) };
    const req = { app: { get: jest.fn().mockReturnValue(io) } };
    emitAdminDashboard(req, 'reason');
    expect(req.app.get).toHaveBeenCalledWith('io');
    expect(emit).toHaveBeenCalled();
  });

  test('no-ops when io is not configured on the app', () => {
    const req = { app: { get: () => null } };
    expect(() => emitAdminDashboard(req, 'x')).not.toThrow();
  });

  test('survives apps without an "app" field', () => {
    expect(() => emitAdminDashboard({}, 'x')).not.toThrow();
  });

  test('catches errors thrown while resolving io and warns once', () => {
    const warn = jest.spyOn(console, 'warn').mockImplementation(() => {});
    try {
      const req = {
        app: {
          get: () => {
            throw new Error('app.get failed');
          },
        },
      };
      expect(() => emitAdminDashboard(req, 'reason', { x: 1 })).not.toThrow();
      const printed = warn.mock.calls.map((args) => args.join(' ')).join('\n');
      expect(printed).toMatch(/\[adminRealtime\] emit failed/);
      expect(printed).toMatch(/app\.get failed/);
    } finally {
      warn.mockRestore();
    }
  });
});
