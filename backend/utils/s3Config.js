const { S3Client, GetObjectCommand, HeadBucketCommand } = require('@aws-sdk/client-s3');
const { getSignedUrl } = require('@aws-sdk/s3-request-presigner');
const multer = require('multer');
const multerS3 = require('multer-s3');
const path = require('path');
require('dotenv').config();

/**
 * Build a full URL for MinIO/S3 API. Accepts `host:port`, `http://host:port`, or `https://...`.
 * Wrong values (e.g. MinIO *console* port instead of API, or double `http://`) break the AWS SDK with XML parse errors.
 */
function normalizeMinioEndpoint(raw) {
  if (!raw || typeof raw !== 'string') return null;
  const t = raw.trim();
  if (!t) return null;
  if (/^https?:\/\//i.test(t)) return t;
  return `http://${t}`;
}

/** Typical MinIO *console* host ports — never use as S3 API (response is HTML/404 text, not S3 XML). */
const MINIO_CONSOLE_HOST_PORTS = new Set(['9001', '9101', '9191']);

function warnIfMinioEndpointLooksLikeConsole(url, envName) {
  if (!url) return;
  try {
    const u = new URL(url);
    const port = u.port || (u.protocol === 'https:' ? '443' : '80');
    if (MINIO_CONSOLE_HOST_PORTS.has(String(port))) {
      console.warn(
        `[S3] ${envName} uses port ${port} (likely MinIO *console*). ` +
          'Use the S3 API host port from docker-compose (e.g. 127.0.0.1:9190), or http://minio:9000 from another container.'
      );
    }
  } catch (_) {
    /* ignore */
  }
}

/** Single-line messages for JSON APIs / Dart clients that reject raw newlines in strings. */
function sanitizeApiErrorMessage(msg) {
  if (!msg || typeof msg !== 'string') return '';
  return msg.replace(/\r?\n/g, ' ').replace(/\s+/g, ' ').trim().slice(0, 400);
}

/**
 * Log first bytes of the HTTP body when the SDK fails to parse XML (wrong port / wrong service).
 * Smithy may leave `body` as Uint8Array, Uint8ArrayBlobAdapter, Readable, or Web ReadableStream.
 * @param {unknown} err
 */
async function logS3SdkErrorResponsePreview(err) {
  const e = err && typeof err === 'object' ? err : null;
  if (e && '$metadata' in e && e.$metadata) {
    console.error('[S3] $metadata:', JSON.stringify(e.$metadata));
  }
  const resp = e && '$response' in e ? e.$response : null;
  if (resp && typeof resp === 'object' && 'headers' in resp && resp.headers) {
    try {
      const h = resp.headers;
      const keys = ['content-type', 'server', 'x-amz-request-id'];
      const pick = {};
      for (const k of keys) {
        const v = h[k] ?? h[k.toLowerCase()];
        if (v != null) pick[k] = v;
      }
      if (Object.keys(pick).length) console.error('[S3] Response headers (subset):', JSON.stringify(pick));
    } catch (_) {
      /* ignore */
    }
  }
  const body = resp && typeof resp === 'object' && 'body' in resp ? resp.body : null;
  if (body == null) {
    console.error('[S3] No $response.body on error.');
    return;
  }
  try {
    let text;
    if (typeof body.transformToString === 'function') {
      const out = body.transformToString();
      text = typeof out === 'string' ? out : await out;
    } else if (Buffer.isBuffer(body)) {
      text = body.toString('utf8');
    } else if (body instanceof Uint8Array) {
      text = Buffer.from(body).toString('utf8');
    } else if (typeof body === 'string') {
      text = body;
    } else if (typeof body.text === 'function') {
      text = await body.text();
    } else if (typeof body.pipe === 'function' && typeof body.on === 'function') {
      const chunks = [];
      await new Promise((resolve, reject) => {
        body.on('data', (c) => chunks.push(c));
        body.on('end', resolve);
        body.on('error', reject);
      });
      text = Buffer.concat(chunks).toString('utf8');
    } else if (body && typeof body.getReader === 'function') {
      const reader = body.getReader();
      const chunks = [];
      for (;;) {
        const { done, value } = await reader.read();
        if (done) break;
        if (value) chunks.push(Buffer.from(value));
      }
      text = Buffer.concat(chunks).toString('utf8');
    } else {
      console.error('[S3] Unknown $response.body type:', body && body.constructor && body.constructor.name);
      return;
    }
    const preview = (text || '').slice(0, 600);
    if (!preview) {
      console.error('[S3] Raw HTTP body is empty (still not S3 XML). Wrong process on this port, or proxy stripped the body.');
    } else {
      console.error('[S3] Raw HTTP body preview (non-S3 or wrong endpoint?):', preview);
    }
    if (resp && typeof resp === 'object' && 'statusCode' in resp) {
      console.error('[S3] HTTP status:', resp.statusCode);
    }
  } catch (readErr) {
    console.error('[S3] Could not read error response body:', readErr && readErr.message);
  }
}

const minioEndpoint = normalizeMinioEndpoint(process.env.MINIO_ENDPOINT);
const minioExternal = normalizeMinioEndpoint(process.env.MINIO_EXTERNAL_URL);

warnIfMinioEndpointLooksLikeConsole(minioEndpoint, 'MINIO_ENDPOINT');
warnIfMinioEndpointLooksLikeConsole(minioExternal, 'MINIO_EXTERNAL_URL');
if (process.env.MINIO_BUCKET && !minioEndpoint) {
  console.warn(
    '[S3] MINIO_BUCKET is set but MINIO_ENDPOINT is missing. The client will talk to real AWS S3; ' +
      'local MinIO credentials will not work. Set MINIO_ENDPOINT (S3 API host port from docker-compose, e.g. 127.0.0.1:9190).'
  );
}

const s3 = new S3Client({
  region: process.env.AWS_REGION || 'us-east-1',
  ...(minioEndpoint ? { endpoint: minioEndpoint, forcePathStyle: true } : {}),
  credentials: {
    accessKeyId: process.env.MINIO_ACCESS_KEY,
    secretAccessKey: process.env.MINIO_SECRET_KEY,
  },
});

if (minioEndpoint && process.env.MINIO_BUCKET) {
  console.log('[S3] Config:', 'endpoint=', minioEndpoint, 'bucket=', process.env.MINIO_BUCKET);
  setImmediate(async () => {
    try {
      await s3.send(new HeadBucketCommand({ Bucket: process.env.MINIO_BUCKET }));
      console.log('[S3] HeadBucket OK — API reachable.');
    } catch (h) {
      const meta = h && h.$metadata;
      const code = h && h.Code;
      const msg = String(h && h.message ? h.message : '');
      if (/S3 API Requests must be made to API port/i.test(msg) || (code === 'InvalidArgument' && msg.includes('API port'))) {
        console.warn(
          '[S3] HeadBucket: MinIO rejected this URL as the *console* port. Use API port only (e.g. :9190 in docker-compose), not :9191. Fix MINIO_ENDPOINT and MINIO_EXTERNAL_URL.'
        );
      } else if (meta && meta.httpStatusCode === 404) {
        console.warn(
          '[S3] HeadBucket: 404 + plain body usually means nothing S3-like on this URL (wrong host/port, or Apache/XAMPP on that port). Match MINIO_ENDPOINT to the compose API port.'
        );
      } else {
        console.warn('[S3] HeadBucket failed:', h && h.name, h && h.message);
      }
      await logS3SdkErrorResponsePreview(h);
    }
  });
}

const generatePresignedUrl = async (keyOrUrl) => {
  if (!keyOrUrl) return null;
  let key = keyOrUrl;
  try {
    // استخراج الـ Key إذا كان المدخل رابطاً كاملاً
    if (keyOrUrl.startsWith('http')) {
      const url = new URL(keyOrUrl);
      let pathname = decodeURIComponent(url.pathname);
      const bucketName = process.env.MINIO_BUCKET;
      if (pathname.includes(`/${bucketName}/`)) {
        key = pathname.split(`/${bucketName}/`)[1];
      } else {
        const parts = pathname.split('/');
        key = parts.slice(2).join('/');
      }
    } else {
      key = decodeURIComponent(keyOrUrl);
    }

    key = key.replace(/^\/+/, ''); // إزالة أي سلاش في البداية

    // تحديد نوع المحتوى للعرض المباشر
    let contentType = 'application/octet-stream';
    const lowerKey = key.toLowerCase();
    if (lowerKey.endsWith('.pdf')) contentType = 'application/pdf';
    else if (lowerKey.endsWith('.jpg') || lowerKey.endsWith('.jpeg')) contentType = 'image/jpeg';
    else if (lowerKey.endsWith('.png')) contentType = 'image/png';
    else if (lowerKey.endsWith('.webp')) contentType = 'image/webp';

    const command = new GetObjectCommand({
      Bucket: process.env.MINIO_BUCKET,
      Key: key,
      ResponseContentType: contentType,
      ResponseContentDisposition: 'inline'
    });

    // توقيع الرابط على العنوان الذي يصل إليه العميل (متصفح / تطبيق)
    const signingEndpoint = minioExternal || minioEndpoint;
    let signingClient = s3;
    if (signingEndpoint && signingEndpoint !== minioEndpoint) {
      signingClient = new S3Client({
        region: process.env.AWS_REGION || 'us-east-1',
        endpoint: signingEndpoint,
        forcePathStyle: true,
        credentials: {
          accessKeyId: process.env.MINIO_ACCESS_KEY,
          secretAccessKey: process.env.MINIO_SECRET_KEY,
        },
      });
    }

    const signedUrl = await getSignedUrl(signingClient, command, { expiresIn: 3600 });
    return signedUrl;
  } catch (error) {
    console.error("[S3] Error generating signed URL:", error);
    return keyOrUrl;
  }
};

const upload = multer({
  storage: multerS3({
    s3: s3,
    bucket: process.env.MINIO_BUCKET,
    metadata: function (req, file, cb) {
      cb(null, { fieldName: file.fieldname });
    },
    key: function (req, file, cb) {
      let folder = 'others';
      if (file.fieldname === 'document') {
         folder = req.body.role === 'driver' ? 'licenses' : 'commercial_docs';
      } else if (file.fieldname === 'epodPhoto') {
        folder = 'epod';
      }
      cb(null, `${folder}/${Date.now().toString()}-${file.originalname}`);
    },
  }),
  fileFilter: (req, file, cb) => {
    // قبول أنواع الـ MIME المعروفة والامتدادات الشائعة
    const allowedMimeTypes = ['image/jpeg', 'image/png', 'image/webp', 'application/pdf', 'application/octet-stream'];
    const allowedExtensions = ['.jpg', '.jpeg', '.png', '.webp', '.pdf'];

    const fileExtension = path.extname(file.originalname).toLowerCase();

    // طباعة تفاصيل الملف في السيرفر للمساعدة في التشخيص
    console.log(`--- [S3 Upload Attempt] ---`);
    console.log(`File Name: ${file.originalname}`);
    console.log(`MIME Type: ${file.mimetype}`);
    console.log(`Extension: ${fileExtension}`);

    if (allowedMimeTypes.includes(file.mimetype) || allowedExtensions.includes(fileExtension)) {
      console.log(`Result: ACCEPTED`);
      cb(null, true);
    } else {
      console.log(`Result: REJECTED`);
      cb(new Error(`نوع الملف غير مدعوم (${file.mimetype}). يرجى رفع صورة أو PDF فقط.`));
    }
  },
  limits: { fileSize: 10 * 1024 * 1024 }
});

module.exports = { s3, upload, generatePresignedUrl, logS3SdkErrorResponsePreview, sanitizeApiErrorMessage };
