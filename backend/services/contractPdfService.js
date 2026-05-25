const fs = require('fs');
const path = require('path');
const os = require('os');
const { pathToFileURL } = require('url');
const puppeteer = require('puppeteer');
const { PutObjectCommand } = require('@aws-sdk/client-s3');
const { s3 } = require('../utils/s3Config');
const pool = require('../config/db');

const FONT_PATH = path.join(__dirname, '../assets/noto/NotoSansArabic-Regular.ttf');
const LOGO_PATH = path.join(__dirname, '../assets/brand/darbak-logo.jpeg');
/** Darbak `primaryGreen` (matches Flutter `DarbakColors.primaryGreen`) */
const THEME_GREEN = '#088A3B';
const SAR_SYMBOL = '⃁';

/** Shared Chromium instance (contracts only; avoids per-PDF cold start). */
let browserPromise = null;

function getBrowser() {
  if (!browserPromise) {
    browserPromise = puppeteer
      .launch({
        headless: true,
        args: [
          '--no-sandbox',
          '--disable-setuid-sandbox',
          '--disable-dev-shm-usage',
          '--font-render-hinting=none',
        ],
      })
      .catch((e) => {
        browserPromise = null;
        throw e;
      });
  }
  return browserPromise;
}

function escapeHtml(text) {
  if (text == null) return '';
  return String(text)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

function shipmentStatusAr(status) {
  const key = (status || '').toString().toLowerCase();
  const map = {
    assigned: 'معيّن لسائق',
    at_pickup: 'عند موقع التحميل',
    en_route: 'في الطريق',
    at_dropoff: 'عند موقع التسليم',
    delivered: 'تم التسليم',
    bidding: 'قيد استلام العروض',
    cancelled: 'ملغاة',
  };
  return map[key] || key;
}

function pad2(n) {
  return String(n).padStart(2, '0');
}

function formatIssueTimestamp(d) {
  return `${d.getFullYear()}/${pad2(d.getMonth() + 1)}/${pad2(d.getDate())} ${pad2(d.getHours())}:${pad2(d.getMinutes())}`;
}

function formatNum2(n) {
  if (!Number.isFinite(n)) return '0.00';
  return n.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
}

/**
 * Renders UTF-8 Arabic contract PDF via Chromium (correct RTL + shaping + embedding).
 * Font file is copied beside the HTML so @font-face can load from the same file: URL.
 */
async function renderContractPdfBuffer(data) {
  if (!fs.existsSync(FONT_PATH)) {
    throw new Error(`[contractPdf] Missing font at ${FONT_PATH}`);
  }

  const tmp = path.join(
    os.tmpdir(),
    `darbak-contract-${Date.now()}-${Math.random().toString(16).slice(2)}`,
  );
  fs.mkdirSync(tmp, { recursive: true });
  const fontFileName = 'NotoSansArabic-Regular.ttf';
  const fontDisk = path.join(tmp, fontFileName);
  fs.copyFileSync(FONT_PATH, fontDisk);

  let logoFileName = null;
  if (fs.existsSync(LOGO_PATH)) {
    logoFileName = 'darbak-logo.jpeg';
    fs.copyFileSync(LOGO_PATH, path.join(tmp, logoFileName));
  }

  const logoBlock = logoFileName
    ? `<div class="brand"><img class="logo" src="${logoFileName}" alt="" /></div>`
    : '';

  const html = `<!DOCTYPE html>
<html dir="rtl" lang="ar">
<head>
<meta charset="utf-8"/>
<style>
@font-face {
  font-family: 'NotoArabic';
  src: url('${fontFileName}') format('truetype');
  font-weight: 400;
  font-style: normal;
  font-display: block;
}
html, body {
  margin: 0;
  padding: 0;
  font-family: 'NotoArabic', sans-serif;
  font-size: 12px;
  line-height: 1.55;
  color: #111;
  background: #fff;
}
.page { padding: 8px 4px 24px 4px; }
.brand { text-align: center; margin: 0 0 12px 0; }
.logo { max-height: 52px; width: auto; display: inline-block; object-fit: contain; }
h1 { font-size: 20px; font-weight: 600; margin: 0 0 8px 0; text-align: center; color: ${THEME_GREEN}; }
.sub { font-size: 10.5px; color: #444; text-align: center; margin-bottom: 20px; line-height: 1.45; }
.meta { font-size: 10px; margin: 12px 0; text-align: right; }
h2 { font-size: 13px; color: ${THEME_GREEN}; margin: 20px 0 8px 0; padding-bottom: 4px; border-bottom: 2px solid ${THEME_GREEN}; }
.row { font-size: 11px; margin: 6px 0; text-align: right; word-wrap: break-word; }
.terms { font-size: 10px; text-align: justify; text-justify: inter-word; margin: 8px 0; line-height: 1.5; }
.num { direction: ltr; unicode-bidi: isolate; display: inline-block; }
</style>
</head>
<body>
<div class="page">
  ${logoBlock}
  <h1>عقد رحلة إلكتروني دربك</h1>
  <div class="sub">وثيقة تلخص الاتفاق التجاري عند قبول الشاحن لعرض السائق داخل تطبيق دربك</div>
  <div class="meta">تاريخ ووقت الإصدار: <span class="num">${escapeHtml(formatIssueTimestamp(data.now))}</span></div>
  <div class="row">رقم الشحنة: <span class="num">${escapeHtml(String(data.shipmentId))}</span></div>
  <div class="row">حالة الشحنة بعد التعاقد: ${escapeHtml(data.statusAr)}</div>

  <h2>تفاصيل الرحلة</h2>
  <div class="row">من الاستلام: ${escapeHtml(data.pickup)}</div>
  <div class="row">إلى التسليم: ${escapeHtml(data.dropoff)}</div>
  <div class="row">وصف البضاعة: ${escapeHtml(data.cargo)}</div>
  <div class="row">الوزن (كجم): <span class="num">${escapeHtml(data.weight)}</span></div>
  <div class="row">السعر الأساسي (${SAR_SYMBOL}): <span class="num">${escapeHtml(data.basePrice)}</span></div>
  <div class="row">المبلغ المتفق عليه (${SAR_SYMBOL}): <span class="num">${escapeHtml(data.bidAmount)}</span></div>
  <div class="row">المدة المتوقعة (أيام): <span class="num">${escapeHtml(data.estimatedDays)}</span></div>

  <h2>بيانات السائق</h2>
  <div class="row">اسم السائق: ${escapeHtml(data.driverName)}</div>
  <div class="row">معرّف السائق: <span class="num">${escapeHtml(String(data.driverId))}</span></div>

  <h2>بيانات الشركة الشاحنة</h2>
  <div class="row">اسم الشاحن: ${escapeHtml(data.shipperName)}</div>
  <div class="row">معرّف الشاحن: <span class="num">${escapeHtml(String(data.shipperId))}</span></div>

  <h2>الشروط والأحكام</h2>
  <p class="terms">يلتزم الطرفان بتنفيذ الشحنة وفق التفاصيل الواردة أعلاه والأنظمة المعمول بها في المملكة العربية السعودية.</p>
  <p class="terms">يُعدّ قبول العرض داخل التطبيق إقراراً بالاطلاع على شروط المنصة والموافقة عليها ضمن نطاق هذه الرحلة.</p>
</div>
</body>
</html>`;

  const htmlPath = path.join(tmp, 'contract.html');
  fs.writeFileSync(htmlPath, html, 'utf8');

  try {
    const browser = await getBrowser();
    const page = await browser.newPage();
    try {
      await page.goto(pathToFileURL(htmlPath).href, {
        waitUntil: 'load',
        timeout: 90_000,
      });
      await page.evaluate(() => document.fonts.ready);
      const pdfUint8 = await page.pdf({
        format: 'A4',
        printBackground: true,
        margin: { top: '14mm', bottom: '14mm', left: '12mm', right: '12mm' },
      });
      return Buffer.from(pdfUint8);
    } finally {
      await page.close().catch(() => {});
    }
  } finally {
    try {
      fs.rmSync(tmp, { recursive: true, force: true });
    } catch (_) {
      /* ignore */
    }
  }
}

/**
 * Builds a PDF contract, uploads to object storage, upserts contracts row.
 * @returns {Promise<{ pdf_key: string, contract_id: number }|null>}
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

  const bidAmount = Number(bid.bid_amount);
  const basePrice = Number(shipment.base_price);
  const weight = Number(shipment.weight_kg);

  const pdfBuffer = await renderContractPdfBuffer({
    now: new Date(),
    shipmentId: shipment.id,
    statusAr: shipmentStatusAr(shipment.status),
    pickup: shipment.pickup_address || '',
    dropoff: shipment.dropoff_address || '',
    cargo: shipment.cargo_description || '',
    weight: formatNum2(weight),
    basePrice: formatNum2(basePrice),
    bidAmount: formatNum2(bidAmount),
    estimatedDays: bid.estimated_days != null ? String(bid.estimated_days) : '',
    driverName: driverName || String(bid.driver_id),
    driverId: bid.driver_id,
    shipperName: shipperName || String(shipment.shipper_id),
    shipperId: shipment.shipper_id,
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

  let contractId = null;
  try {
    await pool.execute(
      `INSERT INTO contracts (shipment_id, bid_id, driver_id, shipper_id, pdf_key)
       VALUES (?, ?, ?, ?, ?)
       ON DUPLICATE KEY UPDATE pdf_key = VALUES(pdf_key), bid_id = VALUES(bid_id)`,
      [shipment.id, bid.id, bid.driver_id, shipment.shipper_id, key],
    );
    const [rows] = await pool.execute(
      'SELECT id FROM contracts WHERE shipment_id = ? LIMIT 1',
      [shipment.id],
    );
    contractId = rows[0]?.id ?? null;
  } catch (e) {
    console.warn('[contractPdf] DB upsert failed (run migrations_05_contracts_fcm.sql):', e.message);
  }

  return contractId != null ? { pdf_key: key, contract_id: contractId } : { pdf_key: key, contract_id: null };
};

process.once('beforeExit', async () => {
  try {
    if (browserPromise) {
      const b = await browserPromise;
      await b.close();
      browserPromise = null;
    }
  } catch (_) {
    /* ignore */
  }
});

module.exports = { generateAndStoreShipmentContract };
