/**
 * Focused shipmentController branch tests.
 *
 * The route suites cover full Express behavior. These tests cover controller
 * branches that are hidden by route validators/auth middleware or by the
 * public GET /api/shipments route not attaching req.user.
 */
'use strict';

const Shipment = require('../../models/Shipment');
const Truck = require('../../models/Truck');
const shipmentController = require('../../controllers/shipmentController');

const makeRes = () => {
  const res = {
    statusCode: 200,
    body: undefined,
    status: jest.fn((code) => {
      res.statusCode = code;
      return res;
    }),
    json: jest.fn((body) => {
      res.body = body;
      return res;
    }),
  };
  return res;
};

describe('shipmentController guards hidden by routes', () => {
  afterEach(() => {
    jest.restoreAllMocks();
  });

  test('createShipment returns validation error when required body fields are missing', async () => {
    const res = makeRes();
    await shipmentController.createShipment({ user: { id: 200 }, body: {} }, res);
    expect(res.status).toHaveBeenCalledWith(400);
    expect(res.body.code).toBe('VALIDATION_ERROR');
  });

  test('getShipmentContractPdfUrl returns 401 when controller receives no user id', async () => {
    const res = makeRes();
    await shipmentController.getShipmentContractPdfUrl(
      { user: null, params: { id: 1000 } },
      res,
    );
    expect(res.status).toHaveBeenCalledWith(401);
  });

  test('updateShipmentStatus returns 500 when shipment lookup throws', async () => {
    jest.spyOn(Shipment, 'findById').mockRejectedValueOnce(new Error('db down'));
    const res = makeRes();
    await shipmentController.updateShipmentStatus(
      {
        user: { id: 100, role: 'driver' },
        params: { id: 1000 },
        body: { status: 'en_route' },
      },
      res,
    );
    expect(res.status).toHaveBeenCalledWith(500);
  });
});

describe('shipmentController listShipments driver truck matching', () => {
  afterEach(() => {
    jest.restoreAllMocks();
  });

  test('returns empty paginated result when driver asks to match truck but has no active truck', async () => {
    jest.spyOn(Truck, 'findActiveByDriverId').mockResolvedValueOnce(null);
    const searchSpy = jest.spyOn(Shipment, 'search');

    const res = makeRes();
    await shipmentController.listShipments(
      {
        user: { id: 100, role: 'driver' },
        query: { matchMyTruck: '1', page: '1', limit: '10' },
      },
      res,
    );

    expect(res.body).toEqual({
      data: [],
      pagination: { page: 1, limit: 10, total: 0, totalPages: 0 },
    });
    expect(searchSpy).not.toHaveBeenCalled();
  });

  test('adds active truck constraints before running Shipment.search', async () => {
    jest.spyOn(Truck, 'findActiveByDriverId').mockResolvedValueOnce({
      category: 'medium_double_5_10',
      max_weight_tons: '9.5',
      axle_count: 2,
      body_type: 'box',
    });
    const searchSpy = jest.spyOn(Shipment, 'search').mockResolvedValueOnce({
      data: [],
      pagination: { page: 1, limit: 10, total: 0, totalPages: 0 },
    });

    const res = makeRes();
    await shipmentController.listShipments(
      {
        user: { id: 100, role: 'driver' },
        query: { matchMyTruck: 'true', page: '1', limit: '10' },
      },
      res,
    );

    expect(res.statusCode).toBe(200);
    expect(searchSpy).toHaveBeenCalledWith({
      filters: expect.objectContaining({
        driverTruckCategory: 'medium_double_5_10',
        driverTruckGroup: expect.any(String),
        driverMaxCapacityTons: 9.5,
        driverAxleCount: 2,
        driverBodyType: 'box',
      }),
      pagination: { page: 1, limit: 10 },
    });
    expect(searchSpy.mock.calls[0][0].filters).not.toHaveProperty('matchMyTruck');
  });
});
