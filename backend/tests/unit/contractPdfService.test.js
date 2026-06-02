/**
 * Unit tests for services/contractPdfService.js. The service is globally
 * stubbed in setup.js, so this suite reaches for the real module via
 * jest.requireActual and isolates puppeteer + s3 dependencies.
 */
'use strict';

const fs = require('fs');
const path = require('path');
const os = require('os');

// Mock puppeteer so no Chromium ever launches. Names must be `mock*` to
// satisfy Jest's hoisted-mock-factory rules.
const mockPdfBytes = Buffer.from('%PDF-1.4 fake');
const mockPage = {
  goto: jest.fn(async () => {}),
  evaluate: jest.fn(async () => {}),
  pdf: jest.fn(async () => new Uint8Array(mockPdfBytes)),
  close: jest.fn(async () => {}),
};
const mockBrowser = {
  newPage: jest.fn(async () => mockPage),
  close: jest.fn(async () => {}),
};
const mockLaunch = jest.fn(async () => mockBrowser);
jest.mock('puppeteer', () => ({ launch: mockLaunch }));

// Mock AWS SDK client commands so we can assert the PutObjectCommand fired.
const mockSend = jest.fn(async () => ({}));
class MockPutObjectCommand {
  constructor(input) {
    this.input = input;
  }
}
jest.mock('@aws-sdk/client-s3', () => ({
  PutObjectCommand: MockPutObjectCommand,
}));

// Override the global s3Config mock for this file so we capture .send().
jest.mock('../../utils/s3Config', () => ({
  s3: { send: mockSend },
}));

// Prevent dotenv from re-populating MINIO_BUCKET from the on-disk .env when
// tests delete it.
jest.mock('dotenv', () => ({ config: jest.fn(() => ({ parsed: {} })) }));

const FONT_PATH = path.join(__dirname, '../../assets/noto/NotoSansArabic-Regular.ttf');
const LOGO_PATH = path.join(__dirname, '../../assets/brand/darbak-logo.jpeg');

// IMPORTANT: do NOT call jest.resetModules here. That would reload our
// helpers/db module and create a NEW dbMock instance, while our `dbMock`
// reference (used to enqueue expectations) still points at the OLD one.
// Instead, just drop the service module from the cache so it picks up the
// fresh `process.env` on each load.
const loadService = () => {
  const servicePath = require.resolve('../../services/contractPdfService');
  delete require.cache[servicePath];
  return jest.requireActual('../../services/contractPdfService');
};

const { dbMock } = require('../helpers/db');

describe('contractPdfService.generateAndStoreShipmentContract', () => {
  let originalBucket;
  let tmpDirsBefore;
  let fontWasFake = false;
  let logoWasFake = false;

  beforeAll(() => {
    if (!fs.existsSync(FONT_PATH)) {
      fs.mkdirSync(path.dirname(FONT_PATH), { recursive: true });
      fs.writeFileSync(FONT_PATH, 'fake-font');
      fontWasFake = true;
    }
    if (!fs.existsSync(LOGO_PATH)) {
      fs.mkdirSync(path.dirname(LOGO_PATH), { recursive: true });
      fs.writeFileSync(LOGO_PATH, 'fake-logo');
      logoWasFake = true;
    }
  });

  afterAll(() => {
    if (fontWasFake && fs.existsSync(FONT_PATH)) fs.unlinkSync(FONT_PATH);
    if (logoWasFake && fs.existsSync(LOGO_PATH)) fs.unlinkSync(LOGO_PATH);
  });

  beforeEach(() => {
    originalBucket = process.env.MINIO_BUCKET;
    tmpDirsBefore = fs.readdirSync(os.tmpdir());
    mockLaunch.mockClear();
    mockSend.mockClear();
    mockPage.goto.mockClear();
    mockPage.pdf.mockClear();
    mockPage.close.mockClear();
  });

  afterEach(() => {
    if (originalBucket === undefined) {
      delete process.env.MINIO_BUCKET;
    } else {
      process.env.MINIO_BUCKET = originalBucket;
    }
  });

  test('returns null when MINIO_BUCKET is not configured', async () => {
    delete process.env.MINIO_BUCKET;
    const { generateAndStoreShipmentContract } = loadService();
    const result = await generateAndStoreShipmentContract({
      shipment: { id: 1, base_price: 100, weight_kg: 5, shipper_id: 9, status: 'assigned' },
      bid: { id: 2, bid_amount: 150, driver_id: 7, estimated_days: 3 },
      shipperName: 'Test Shipper',
      driverName: 'Test Driver',
    });
    expect(result).toBeNull();
    expect(mockLaunch).not.toHaveBeenCalled();
  });

  test('builds the PDF, uploads to S3, and upserts contracts row', async () => {
    process.env.MINIO_BUCKET = 'darbak';
    dbMock.expectInsert(/INSERT INTO contracts/i).returnsInsert(77);
    dbMock
      .expectSelect(/SELECT id FROM contracts WHERE shipment_id = \?/i)
      .returns([{ id: 77 }]);

    const { generateAndStoreShipmentContract } = loadService();
    const result = await generateAndStoreShipmentContract({
      shipment: {
        id: 101,
        base_price: 200,
        weight_kg: 12.5,
        shipper_id: 41,
        status: 'assigned',
        pickup_address: 'الرياض',
        dropoff_address: 'جدة',
        cargo_description: 'بضائع',
      },
      bid: { id: 55, bid_amount: 800, driver_id: 9, estimated_days: 2 },
      shipperName: 'شركة الشاحن',
      driverName: 'السائق التجريبي',
    });

    expect(result).toEqual({
      pdf_key: expect.stringMatching(/^contracts\/shipment-101-/),
      contract_id: 77,
    });
    expect(mockLaunch).toHaveBeenCalledTimes(1);
    expect(mockSend).toHaveBeenCalledTimes(1);
    const putCmd = mockSend.mock.calls[0][0];
    expect(putCmd).toBeInstanceOf(MockPutObjectCommand);
    expect(putCmd.input.Bucket).toBe('darbak');
    expect(putCmd.input.ContentType).toBe('application/pdf');
    expect(Buffer.isBuffer(putCmd.input.Body)).toBe(true);
  });

  test('returns pdf_key with null contract_id when DB upsert fails', async () => {
    process.env.MINIO_BUCKET = 'darbak';
    dbMock
      .expectInsert(/INSERT INTO contracts/i)
      .rejectsWith(new Error('contracts table missing'));

    const { generateAndStoreShipmentContract } = loadService();
    const result = await generateAndStoreShipmentContract({
      shipment: {
        id: 5,
        base_price: 100,
        weight_kg: 1,
        shipper_id: 1,
        status: 'bidding',
      },
      bid: { id: 6, bid_amount: 200, driver_id: 1, estimated_days: null },
      shipperName: null,
      driverName: null,
    });

    expect(result).toEqual({
      pdf_key: expect.stringMatching(/^contracts\/shipment-5-/),
      contract_id: null,
    });
  });

  test('handles missing optional fields gracefully', async () => {
    process.env.MINIO_BUCKET = 'darbak';
    dbMock.expectInsert(/INSERT INTO contracts/i).returnsInsert(1);
    dbMock
      .expectSelect(/SELECT id FROM contracts WHERE shipment_id = \?/i)
      .returns([]);

    const { generateAndStoreShipmentContract } = loadService();
    const result = await generateAndStoreShipmentContract({
      shipment: {
        id: 9,
        base_price: 'invalid',
        weight_kg: null,
        shipper_id: 2,
        status: undefined,
      },
      bid: { id: 11, bid_amount: undefined, driver_id: 3, estimated_days: undefined },
    });
    expect(result).toEqual({
      pdf_key: expect.stringMatching(/^contracts\/shipment-9-/),
      contract_id: null,
    });
  });

  test('propagates puppeteer page errors and surfaces them to the caller', async () => {
    process.env.MINIO_BUCKET = 'darbak';
    // Earlier tests already prime the shared `browserPromise` inside the
    // service via successful `puppeteer.launch` calls. Forcing the *page*
    // pipeline to throw is a cleaner failure surface and avoids fighting
    // the shared-browser cache. We still validate that errors bubble out
    // of `generateAndStoreShipmentContract` rather than being swallowed.
    mockPage.goto.mockImplementationOnce(async () => {
      throw new Error('chromium-crash');
    });

    const { generateAndStoreShipmentContract } = loadService();
    await expect(
      generateAndStoreShipmentContract({
        shipment: { id: 1, base_price: 1, weight_kg: 1, shipper_id: 1, status: 'assigned' },
        bid: { id: 1, bid_amount: 1, driver_id: 1, estimated_days: 0 },
      }),
    ).rejects.toThrow('chromium-crash');
    expect(mockPage.close).toHaveBeenCalled();
  });

  test('throws when the bundled Arabic font is missing', async () => {
    process.env.MINIO_BUCKET = 'darbak';
    if (fontWasFake) {
      fs.unlinkSync(FONT_PATH);
    } else {
      const backup = `${FONT_PATH}.bak`;
      fs.renameSync(FONT_PATH, backup);
      try {
        const { generateAndStoreShipmentContract } = loadService();
        await expect(
          generateAndStoreShipmentContract({
            shipment: { id: 1, base_price: 1, weight_kg: 1, shipper_id: 1, status: 'assigned' },
            bid: { id: 1, bid_amount: 1, driver_id: 1, estimated_days: 0 },
          }),
        ).rejects.toThrow(/Missing font/);
      } finally {
        fs.renameSync(backup, FONT_PATH);
      }
      return;
    }
    const { generateAndStoreShipmentContract } = loadService();
    await expect(
      generateAndStoreShipmentContract({
        shipment: { id: 1, base_price: 1, weight_kg: 1, shipper_id: 1, status: 'assigned' },
        bid: { id: 1, bid_amount: 1, driver_id: 1, estimated_days: 0 },
      }),
    ).rejects.toThrow(/Missing font/);
    // Restore for any subsequent tests:
    fs.writeFileSync(FONT_PATH, 'fake-font');
  });
});
