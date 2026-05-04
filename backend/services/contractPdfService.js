const fs = require('fs');
const path = require('path');
const PDFDocument = require('pdfkit');
const { PutObjectCommand } = require('@aws-sdk/client-s3');
const { s3 } = require('../utils/s3Config');
const pool = require('../config/db');

const FONT_PATH = path.join(__dirname, '../assets/noto/NotoSansArabic-Regular.ttf');

/**
 * Builds a PDF contract, uploads to object storage, inserts contracts row.
 * @returns {Promise<string|null>} S3 object key, or null on failure
 */
const generateAndStoreShipmentContract = async ({
  shipment,
  bid,
  shipperName,
  driverName,
}) => {
  if (!process.env.MINIO_BUCKET) {
    console.warn('[contractPdf] MINIO_BUCKET not set');
    return null;
  }

  const pdfBuffer = await new Promise((resolve, reject) => {
    const chunks = [];
    const doc = new PDFDocument({ margin: 48, size: 'A4' });
    doc.on('data', (c) => chunks.push(c));
    doc.on('error', reject);
    doc.on('end', () => resolve(Buffer.concat(chunks)));

    try {
      if (fs.existsSync(FONT_PATH)) {
        doc.registerFont('Body', FONT_PATH);
        doc.font('Body');
      }
    } catch (_) {
      /* use default font */
    }

    const now = new Date().toISOString();
    doc.fontSize(18).text('Darbak — Electronic Trip Contract', { align: 'center' });
    doc.moveDown();
    doc.fontSize(11).text(`Generated: ${now}`, { align: 'center' });
    doc.moveDown(2);

    doc.fontSize(12).text(`Shipment ID: ${shipment.id}`);
    doc.text(`Status: ${shipment.status}`);
    doc.moveDown();
    doc.text(`Origin (pickup): ${shipment.pickup_address || ''}`);
    doc.text(`Destination (dropoff): ${shipment.dropoff_address || ''}`);
    doc.text(`Cargo: ${shipment.cargo_description || ''}`);
    doc.text(`Weight (kg): ${shipment.weight_kg}`);
    doc.text(`Base price (SAR): ${shipment.base_price}`);
    doc.moveDown();
    doc.text(`Agreed bid amount (SAR): ${bid.bid_amount}`);
    doc.text(`Estimated days: ${bid.estimated_days}`);
    doc.moveDown();
    doc.text(`Shipper / company: ${shipperName || shipment.shipper_id}`);
    doc.text(`Driver: ${driverName || bid.driver_id}`);
    doc.moveDown(2);
    doc.fontSize(10).text(
      'Terms: This contract records the commercial agreement accepted in the Darbak app when the shipper accepted the driver\'s offer. '
        + 'Parties agree to execute the shipment per shipment details and applicable regulations. '
        + 'Disputes follow the governing terms of the platform and local law.',
      { align: 'left' },
    );

    doc.end();
  });

  const key = `contracts/shipment-${shipment.id}-${Date.now()}.pdf`;
  await s3.send(
    new PutObjectCommand({
      Bucket: process.env.MINIO_BUCKET,
      Key: key,
      Body: pdfBuffer,
      ContentType: 'application/pdf',
    }),
  );

  try {
    await pool.execute(
      `INSERT INTO contracts (shipment_id, bid_id, driver_id, shipper_id, pdf_key)
       VALUES (?, ?, ?, ?, ?)
       ON DUPLICATE KEY UPDATE pdf_key = VALUES(pdf_key), bid_id = VALUES(bid_id)`,
      [shipment.id, bid.id, bid.driver_id, shipment.shipper_id, key],
    );
  } catch (e) {
    console.warn('[contractPdf] DB insert failed (run migrations_05_contracts_fcm.sql):', e.message);
  }

  return key;
};

module.exports = { generateAndStoreShipmentContract };
