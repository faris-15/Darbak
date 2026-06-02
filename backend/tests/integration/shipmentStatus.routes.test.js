/**
 * Integration tests for /api/shipment-status/* (shipmentStatusController +
 * shipmentStatusRoutes + ShipmentStatus model).
 */
'use strict';

const request = require('supertest');

const { buildTestApp } = require('../helpers/testApp');
const { dbMock } = require('../helpers/db');
const { shipmentFactory } = require('../helpers/factories');

const app = () => buildTestApp({ routes: ['shipmentStatus'] });

// Shipment.findById issues a complex SELECT, route it to a stub when needed.
const expectFindShipment = (row) =>
  dbMock.expectSelect(/FROM shipments s\s+LEFT JOIN users sh/i).returns(row ? [row] : []);

describe('POST /api/shipment-status', () => {
  test('400 when shipment_id missing', async () => {
    const res = await request(app()).post('/api/shipment-status').send({ status: 'assigned' });
    expect(res.status).toBe(400);
    expect(res.body.message).toMatch(/مطلوبة/);
  });

  test('400 when status missing', async () => {
    const res = await request(app()).post('/api/shipment-status').send({ shipment_id: 1 });
    expect(res.status).toBe(400);
  });

  test('404 when shipment does not exist', async () => {
    expectFindShipment(null);
    const res = await request(app())
      .post('/api/shipment-status')
      .send({ shipment_id: 1, status: 'assigned' });
    expect(res.status).toBe(404);
  });

  test('201 records status and updates the shipment for allowed states', async () => {
    expectFindShipment(shipmentFactory({ id: 1 }));
    dbMock.expectInsert(/INSERT INTO shipment_status_history/i).returnsInsert(11);
    dbMock.expectUpdate(/UPDATE shipments SET status = \?/i).returnsAffected(1);

    const res = await request(app()).post('/api/shipment-status').send({
      shipment_id: 1,
      status: 'en_route',
      location_lat: 24.7,
      location_lng: 46.6,
      photo_path: null,
    });
    expect(res.status).toBe(201);
    expect(res.body.id).toBe(11);
    expect(res.body.status).toBe('en_route');
  });

  test('201 does NOT update shipment for non-allowed state', async () => {
    expectFindShipment(shipmentFactory({ id: 1 }));
    dbMock.expectInsert(/INSERT INTO shipment_status_history/i).returnsInsert(12);
    // No UPDATE expected.

    const res = await request(app())
      .post('/api/shipment-status')
      .send({ shipment_id: 1, status: 'note' });
    expect(res.status).toBe(201);
  });

  test('500 when an insert fails', async () => {
    expectFindShipment(shipmentFactory({ id: 1 }));
    dbMock.expectInsert(/INSERT INTO shipment_status_history/i).rejectsWith(new Error('boom'));
    const res = await request(app())
      .post('/api/shipment-status')
      .send({ shipment_id: 1, status: 'assigned' });
    expect(res.status).toBe(500);
  });
});

describe('GET /api/shipment-status/:shipment_id/history', () => {
  test('404 when shipment missing', async () => {
    expectFindShipment(null);
    const res = await request(app()).get('/api/shipment-status/1/history');
    expect(res.status).toBe(404);
  });

  test('200 returns history', async () => {
    expectFindShipment(shipmentFactory({ id: 1 }));
    dbMock
      .expectSelect(/FROM shipment_status_history WHERE shipment_id = \? ORDER BY updated_at ASC/i)
      .returns([{ id: 1, status: 'assigned' }]);
    const res = await request(app()).get('/api/shipment-status/1/history');
    expect(res.status).toBe(200);
    expect(res.body.history).toEqual([{ id: 1, status: 'assigned' }]);
  });

  test('500 on DB error', async () => {
    expectFindShipment(shipmentFactory({ id: 1 }));
    dbMock
      .expectSelect(/FROM shipment_status_history WHERE shipment_id = \? ORDER BY updated_at ASC/i)
      .rejectsWith(new Error('boom'));
    const res = await request(app()).get('/api/shipment-status/1/history');
    expect(res.status).toBe(500);
  });
});

describe('GET /api/shipment-status/:shipment_id/latest', () => {
  test('404 when no rows', async () => {
    dbMock
      .expectSelect(/FROM shipment_status_history WHERE shipment_id = \? ORDER BY updated_at DESC/i)
      .returns([]);
    const res = await request(app()).get('/api/shipment-status/1/latest');
    expect(res.status).toBe(404);
  });

  test('200 returns the latest', async () => {
    dbMock
      .expectSelect(/FROM shipment_status_history WHERE shipment_id = \? ORDER BY updated_at DESC/i)
      .returns([{ id: 9, status: 'en_route' }]);
    const res = await request(app()).get('/api/shipment-status/1/latest');
    expect(res.status).toBe(200);
    expect(res.body).toEqual({ id: 9, status: 'en_route' });
  });

  test('500 on DB error', async () => {
    dbMock
      .expectSelect(/FROM shipment_status_history/i)
      .rejectsWith(new Error('boom'));
    const res = await request(app()).get('/api/shipment-status/1/latest');
    expect(res.status).toBe(500);
  });
});

describe('GET /api/shipment-status/:shipment_id/pod-photo', () => {
  test('404 when no POD photo', async () => {
    dbMock
      .expectSelect(/SELECT photo_path FROM shipment_status_history/i)
      .returns([]);
    const res = await request(app()).get('/api/shipment-status/1/pod-photo');
    expect(res.status).toBe(404);
  });

  test('200 returns the photo path', async () => {
    dbMock
      .expectSelect(/SELECT photo_path FROM shipment_status_history/i)
      .returns([{ photo_path: 'pod/1.jpg' }]);
    const res = await request(app()).get('/api/shipment-status/1/pod-photo');
    expect(res.status).toBe(200);
    expect(res.body.photo_path).toBe('pod/1.jpg');
  });

  test('500 on DB error', async () => {
    dbMock.expectSelect(/SELECT photo_path/i).rejectsWith(new Error('x'));
    const res = await request(app()).get('/api/shipment-status/1/pod-photo');
    expect(res.status).toBe(500);
  });
});
