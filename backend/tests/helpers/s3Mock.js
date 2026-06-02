/**
 * Mock for `backend/utils/s3Config.js`. Returns deterministic presigned URLs,
 * passes uploads through (recording them on `s3Mock`), and lets tests assert
 * S3 interactions without hitting MinIO/AWS.
 */
'use strict';

const recorded = {
  uploads: [],
  presigned: [],
  deletes: [],
};

/**
 * Tests can inject a `__testFile` payload into the request body to simulate
 * a real multer upload regardless of which `single()` field name the route
 * is calling. Any of `document` / `image` / `media` / `operatingCard` /
 * `profileImage` / `__testFile` are recognised. The handler is reset on every
 * call so per-test mutations cannot leak between suites.
 */
const passthroughMulter = (fieldName = 'file') => {
  const handler = (req, _res, next) => {
    if (req.file) return next();
    const candidates = [
      fieldName,
      'document',
      'image',
      'media',
      'operatingCard',
      'profileImage',
      'epodPhoto',
      '__testFile',
    ];
    for (const name of candidates) {
      const val = req.body?.[name];
      if (!val) continue;
      if (typeof val === 'object') {
        req.file = val;
        return next();
      }
      if (typeof val === 'string') {
        req.file = {
          key: val,
          location: `https://test-s3.local/${val}`,
          mimetype: 'application/octet-stream',
        };
        return next();
      }
    }
    next();
  };
  return {
    single: () => handler,
    any: () => (_req, _res, next) => next(),
  };
};

const s3Mock = {
  s3: { send: jest.fn(async () => ({})) },

  upload: passthroughMulter('document'),
  profileImageUpload: passthroughMulter('image'),
  chatMediaUpload: passthroughMulter('media'),

  generatePresignedUrl: jest.fn(async (key) => {
    if (!key) return null;
    recorded.presigned.push(key);
    return `https://test-s3.local/presigned/${encodeURIComponent(key)}?sig=test`;
  }),

  deleteS3Object: jest.fn(async (key) => {
    if (!key) return;
    recorded.deletes.push(key);
  }),

  resolveS3ObjectKey: jest.fn((key) => key),
  logS3SdkErrorResponsePreview: jest.fn(async () => {}),
  sanitizeApiErrorMessage: (msg) =>
    String(msg || '').replace(/\r?\n/g, ' ').replace(/\s+/g, ' ').trim().slice(0, 400),

  __recorded: recorded,
  __reset() {
    recorded.uploads.length = 0;
    recorded.presigned.length = 0;
    recorded.deletes.length = 0;
  },
};

module.exports = s3Mock;
