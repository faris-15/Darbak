/**
 * Integration tests for /api/payout/* (payoutController + payoutService).
 * The service is pure (no DB), so we drive everything through the HTTP layer.
 */
'use strict';

const request = require('supertest');

const { buildTestApp } = require('../helpers/testApp');
const { calculatePayout } = require('../../services/payoutService');

const app = () => buildTestApp({ routes: ['payout'] });

describe('POST /api/payout', () => {
  test('400 when totalAmount is not numeric', async () => {
    const res = await request(app())
      .post('/api/payout')
      .send({ totalAmount: 'abc', edt: '2026-01-10', actualDeliveryDate: '2026-01-12' });
    expect(res.status).toBe(400);
  });

  test('400 when edt is not ISO8601', async () => {
    const res = await request(app())
      .post('/api/payout')
      .send({ totalAmount: 1000, edt: 'tomorrow', actualDeliveryDate: '2026-01-12' });
    expect(res.status).toBe(400);
  });

  test('400 when fields are missing in the controller after validator passes', async () => {
    // edt 0 still passes isNumeric/isISO8601 → goes into controller where we
    // verify it short-circuits on falsy totalAmount. supertest body must
    // satisfy validator, so we send via direct controller invocation here.
    const { computePayout } = require('../../controllers/payoutController');
    const json = jest.fn();
    const status = jest.fn(() => ({ json }));
    await computePayout(
      { body: { totalAmount: 0, edt: '2026-01-10', actualDeliveryDate: '2026-01-12' } },
      { status, json }
    );
    expect(status).toHaveBeenCalledWith(400);
  });

  test('200 returns ontime payout (no deduction)', async () => {
    const res = await request(app())
      .post('/api/payout')
      .send({
        totalAmount: 1000,
        edt: '2026-01-10T00:00:00.000Z',
        actualDeliveryDate: '2026-01-10T00:00:00.000Z',
      });
    expect(res.status).toBe(200);
    expect(res.body).toMatchObject({
      totalAmount: 1000,
      delayDays: 0,
      deductionRate: 0,
      finalAmount: 1000,
    });
  });

  test('200 applies 5% per delayed day', async () => {
    const res = await request(app())
      .post('/api/payout')
      .send({
        totalAmount: 1000,
        edt: '2026-01-10T00:00:00.000Z',
        actualDeliveryDate: '2026-01-13T00:00:00.000Z',
      });
    expect(res.status).toBe(200);
    expect(res.body.delayDays).toBe(3);
    expect(res.body.deductionRate).toBeCloseTo(0.15, 6);
    expect(res.body.finalAmount).toBeCloseTo(850, 6);
  });

  test('200 caps deduction at 25%', async () => {
    const res = await request(app())
      .post('/api/payout')
      .send({
        totalAmount: 1000,
        edt: '2026-01-10T00:00:00.000Z',
        actualDeliveryDate: '2026-01-30T00:00:00.000Z',
      });
    expect(res.status).toBe(200);
    expect(res.body.deductionRate).toBe(0.25);
    expect(res.body.finalAmount).toBe(750);
  });

  test('controller returns 500 when the service throws', async () => {
    // Reset the module cache so we can stub the service before re-requiring
    // the controller. We use isolateModules to avoid leaking the mock.
    jest.isolateModules(() => {
      jest.doMock('../../services/payoutService', () => ({
        calculatePayout: () => {
          throw new Error('boom');
        },
      }));
      const { computePayout } = require('../../controllers/payoutController');
      const json = jest.fn();
      const status = jest.fn(() => ({ json }));
      computePayout(
        {
          body: {
            totalAmount: 1000,
            edt: '2026-01-10T00:00:00.000Z',
            actualDeliveryDate: '2026-01-11T00:00:00.000Z',
          },
        },
        { status, json }
      );
      expect(status).toHaveBeenCalledWith(500);
    });
  });
});

describe('payoutService.calculatePayout (unit)', () => {
  test('delayDays uses Math.ceil so partial-day delays round up', () => {
    const r = calculatePayout({
      totalAmount: 100,
      edt: '2026-01-10T00:00:00.000Z',
      actualDeliveryDate: '2026-01-10T18:00:00.000Z',
    });
    expect(r.delayDays).toBe(1);
    expect(r.deductionRate).toBeCloseTo(0.05);
  });

  test('handles same-second delivery', () => {
    const r = calculatePayout({
      totalAmount: 100,
      edt: '2026-01-10T00:00:00.000Z',
      actualDeliveryDate: '2026-01-10T00:00:00.000Z',
    });
    expect(r.delayDays).toBe(0);
    expect(r.finalAmount).toBe(100);
  });
});
