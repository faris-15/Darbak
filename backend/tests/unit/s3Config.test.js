/**
 * Unit tests for the *real* utils/s3Config helpers (the file is globally
 * mocked in setup.js, so we use jest.requireActual). The AWS SDK calls
 * are stubbed so no network traffic occurs.
 */
'use strict';

jest.mock('@aws-sdk/client-s3', () => {
  const send = jest.fn(async () => ({}));
  class S3Client {
    constructor(cfg) {
      this.cfg = cfg;
      this.send = send;
    }
  }
  class GetObjectCommand {
    constructor(input) {
      this.input = input;
    }
  }
  class HeadBucketCommand {
    constructor(input) {
      this.input = input;
    }
  }
  class DeleteObjectCommand {
    constructor(input) {
      this.input = input;
    }
  }
  class PutObjectCommand {
    constructor(input) {
      this.input = input;
    }
  }
  return {
    S3Client,
    GetObjectCommand,
    HeadBucketCommand,
    DeleteObjectCommand,
    PutObjectCommand,
    __send: send,
  };
});

jest.mock('@aws-sdk/s3-request-presigner', () => ({
  getSignedUrl: jest.fn(async (_c, command, _opts) => {
    const key = command.input?.Key || '';
    return `https://signed.test/${encodeURIComponent(key)}`;
  }),
}));

// Multer + multer-s3 are heavy, we just need their constructors to be callable.
jest.mock('multer', () => {
  const fn = jest.fn((opts) => ({ opts, single: jest.fn(), any: jest.fn() }));
  return fn;
});
jest.mock('multer-s3', () => jest.fn((opts) => opts));
// Prevent dotenv from re-loading the on-disk .env and re-populating MINIO_*
// after the test deletes those variables.
jest.mock('dotenv', () => ({ config: jest.fn(() => ({ parsed: {} })) }));

const loadReal = () => {
  jest.resetModules();
  return jest.requireActual('../../utils/s3Config');
};

describe('s3Config — utility helpers', () => {
  let originalEnv;
  beforeEach(() => {
    originalEnv = { ...process.env };
    delete process.env.MINIO_ENDPOINT;
    delete process.env.MINIO_EXTERNAL_URL;
    delete process.env.MINIO_BUCKET;
  });
  afterEach(() => {
    process.env = originalEnv;
  });

  describe('resolveS3ObjectKey', () => {
    test('returns "" for empty / non-string input', () => {
      const { resolveS3ObjectKey } = loadReal();
      expect(resolveS3ObjectKey('')).toBe('');
      expect(resolveS3ObjectKey(null)).toBe('');
      expect(resolveS3ObjectKey(undefined)).toBe('');
      expect(resolveS3ObjectKey(123)).toBe('');
    });

    test('returns raw key when input is not a URL', () => {
      const { resolveS3ObjectKey } = loadReal();
      expect(resolveS3ObjectKey('folder/file.pdf')).toBe('folder/file.pdf');
      expect(resolveS3ObjectKey('/leading/slash.png')).toBe('leading/slash.png');
    });

    test('strips bucket prefix from full MinIO URL', () => {
      process.env.MINIO_BUCKET = 'darbak';
      const { resolveS3ObjectKey } = loadReal();
      expect(
        resolveS3ObjectKey('http://localhost:9000/darbak/contracts/abc.pdf'),
      ).toBe('contracts/abc.pdf');
    });

    test('handles bucket as first path segment without the wrapper /bucket/ pattern', () => {
      process.env.MINIO_BUCKET = 'darbak';
      const { resolveS3ObjectKey } = loadReal();
      // No "/darbak/" sub-string but parts[0] === bucket
      expect(resolveS3ObjectKey('http://h/darbak')).toBe('');
    });

    test('falls back to remainder when bucket env is missing', () => {
      const { resolveS3ObjectKey } = loadReal();
      expect(resolveS3ObjectKey('https://host/a/b/c.pdf')).toBe('b/c.pdf');
    });

    test('returns empty string when URL parsing throws', () => {
      const { resolveS3ObjectKey } = loadReal();
      // The leading http:// makes the early regex match, then `new URL`
      // sometimes still parses it; provide an obviously malformed value.
      expect(resolveS3ObjectKey('http://')).toBe('');
    });

    test('decodes percent-encoded raw keys', () => {
      const { resolveS3ObjectKey } = loadReal();
      expect(resolveS3ObjectKey('folder/file%20name.pdf')).toBe(
        'folder/file name.pdf',
      );
    });
  });

  describe('sanitizeApiErrorMessage', () => {
    test('collapses whitespace + newlines and trims to 400 chars', () => {
      const { sanitizeApiErrorMessage } = loadReal();
      expect(sanitizeApiErrorMessage('  hello\r\nworld\n   ')).toBe(
        'hello world',
      );
      expect(sanitizeApiErrorMessage(null)).toBe('');
      expect(sanitizeApiErrorMessage(42)).toBe('');
      const big = 'x'.repeat(800);
      expect(sanitizeApiErrorMessage(big)).toHaveLength(400);
    });
  });

  describe('generatePresignedUrl', () => {
    test('returns null when key is empty', async () => {
      const { generatePresignedUrl } = loadReal();
      expect(await generatePresignedUrl(null)).toBeNull();
      expect(await generatePresignedUrl('')).toBeNull();
    });

    test('signs the URL using the standard endpoint', async () => {
      process.env.MINIO_BUCKET = 'darbak';
      const { generatePresignedUrl } = loadReal();
      const url = await generatePresignedUrl('contracts/abc.pdf');
      expect(url).toContain('signed.test');
      expect(url).toContain('contracts');
    });

    test('uses content-type heuristics for known extensions', async () => {
      const { generatePresignedUrl } = loadReal();
      const presigner = require('@aws-sdk/s3-request-presigner');
      await generatePresignedUrl('files/photo.JPG');
      await generatePresignedUrl('files/video.mp4');
      await generatePresignedUrl('files/audio.mov');
      await generatePresignedUrl('files/clip.M4V');
      await generatePresignedUrl('files/doc.pdf');
      await generatePresignedUrl('files/sticker.gif');
      await generatePresignedUrl('files/photo.heic');
      await generatePresignedUrl('files/photo.HEIF');
      await generatePresignedUrl('files/photo.WEBP');
      await generatePresignedUrl('files/photo.png');
      await generatePresignedUrl('files/unknown.bin');
      const types = presigner.getSignedUrl.mock.calls.map(
        ([, command]) => command.input.ResponseContentType,
      );
      expect(types).toEqual(
        expect.arrayContaining([
          'image/jpeg',
          'video/mp4',
          'video/quicktime',
          'video/x-m4v',
          'application/pdf',
          'image/gif',
          'image/heic',
          'image/heif',
          'image/webp',
          'image/png',
          'application/octet-stream',
        ]),
      );
    });

    test('uses external signing endpoint when configured separately', async () => {
      process.env.MINIO_ENDPOINT = 'http://internal:9000';
      process.env.MINIO_EXTERNAL_URL = 'http://public:9000';
      process.env.MINIO_BUCKET = 'darbak';
      const { generatePresignedUrl } = loadReal();
      const url = await generatePresignedUrl('a/b.pdf');
      expect(url).toContain('signed.test');
    });

    test('returns the original key when signing throws', async () => {
      const { generatePresignedUrl } = loadReal();
      const presigner = require('@aws-sdk/s3-request-presigner');
      presigner.getSignedUrl.mockImplementationOnce(async () => {
        throw new Error('boom');
      });
      const url = await generatePresignedUrl('a.pdf');
      expect(url).toBe('a.pdf');
    });
  });

  describe('deleteS3Object', () => {
    test('returns false on empty/null key', async () => {
      const { deleteS3Object } = loadReal();
      expect(await deleteS3Object('')).toBe(false);
      expect(await deleteS3Object(null)).toBe(false);
    });

    test('sends DeleteObjectCommand for valid key', async () => {
      process.env.MINIO_BUCKET = 'darbak';
      const { deleteS3Object } = loadReal();
      const { __send } = require('@aws-sdk/client-s3');
      __send.mockClear();
      const ok = await deleteS3Object('a/b.pdf');
      expect(ok).toBe(true);
      expect(__send).toHaveBeenCalledTimes(1);
      const cmd = __send.mock.calls[0][0];
      expect(cmd.input).toEqual({ Bucket: 'darbak', Key: 'a/b.pdf' });
    });
  });

  describe('logS3SdkErrorResponsePreview', () => {
    test('logs $metadata when present', async () => {
      const { logS3SdkErrorResponsePreview } = loadReal();
      const spy = jest.spyOn(console, 'error').mockImplementation(() => {});
      try {
        await logS3SdkErrorResponsePreview({
          $metadata: { httpStatusCode: 500 },
          $response: { headers: { 'content-type': 'text/html' }, body: null },
        });
        expect(spy).toHaveBeenCalled();
      } finally {
        spy.mockRestore();
      }
    });

    test('reads Buffer body and previews it', async () => {
      const { logS3SdkErrorResponsePreview } = loadReal();
      const spy = jest.spyOn(console, 'error').mockImplementation(() => {});
      try {
        await logS3SdkErrorResponsePreview({
          $response: {
            headers: { 'content-type': 'text/html' },
            body: Buffer.from('<html>nope</html>'),
            statusCode: 404,
          },
        });
        const printed = spy.mock.calls.map((args) => args.join(' ')).join('\n');
        expect(printed).toMatch(/Raw HTTP body preview/);
        expect(printed).toMatch(/nope/);
      } finally {
        spy.mockRestore();
      }
    });

    test('reads body via transformToString()', async () => {
      const { logS3SdkErrorResponsePreview } = loadReal();
      const spy = jest.spyOn(console, 'error').mockImplementation(() => {});
      try {
        const body = { transformToString: () => '<html>err</html>' };
        await logS3SdkErrorResponsePreview({ $response: { body } });
        const printed = spy.mock.calls.map((args) => args.join(' ')).join('\n');
        expect(printed).toMatch(/err/);
      } finally {
        spy.mockRestore();
      }
    });

    test('reads body via async transformToString()', async () => {
      const { logS3SdkErrorResponsePreview } = loadReal();
      const spy = jest.spyOn(console, 'error').mockImplementation(() => {});
      try {
        const body = { transformToString: async () => 'async-body' };
        await logS3SdkErrorResponsePreview({ $response: { body } });
        const printed = spy.mock.calls.map((args) => args.join(' ')).join('\n');
        expect(printed).toMatch(/async-body/);
      } finally {
        spy.mockRestore();
      }
    });

    test('reads body via text()', async () => {
      const { logS3SdkErrorResponsePreview } = loadReal();
      const spy = jest.spyOn(console, 'error').mockImplementation(() => {});
      try {
        const body = { text: async () => 'text-body' };
        await logS3SdkErrorResponsePreview({ $response: { body } });
        const printed = spy.mock.calls.map((args) => args.join(' ')).join('\n');
        expect(printed).toMatch(/text-body/);
      } finally {
        spy.mockRestore();
      }
    });

    test('reads body via Node stream pipe', async () => {
      const { logS3SdkErrorResponsePreview } = loadReal();
      const spy = jest.spyOn(console, 'error').mockImplementation(() => {});
      try {
        const { Readable } = require('stream');
        const body = Readable.from([Buffer.from('stream-'), Buffer.from('body')]);
        await logS3SdkErrorResponsePreview({ $response: { body } });
        const printed = spy.mock.calls.map((args) => args.join(' ')).join('\n');
        expect(printed).toMatch(/stream-body/);
      } finally {
        spy.mockRestore();
      }
    });

    test('reads body via Uint8Array', async () => {
      const { logS3SdkErrorResponsePreview } = loadReal();
      const spy = jest.spyOn(console, 'error').mockImplementation(() => {});
      try {
        const body = new Uint8Array(Buffer.from('uint8-body'));
        await logS3SdkErrorResponsePreview({ $response: { body } });
        const printed = spy.mock.calls.map((args) => args.join(' ')).join('\n');
        expect(printed).toMatch(/uint8-body/);
      } finally {
        spy.mockRestore();
      }
    });

    test('reads body via plain string', async () => {
      const { logS3SdkErrorResponsePreview } = loadReal();
      const spy = jest.spyOn(console, 'error').mockImplementation(() => {});
      try {
        await logS3SdkErrorResponsePreview({
          $response: { body: 'plain-str-body' },
        });
        const printed = spy.mock.calls.map((args) => args.join(' ')).join('\n');
        expect(printed).toMatch(/plain-str-body/);
      } finally {
        spy.mockRestore();
      }
    });

    test('reads body via web ReadableStream getReader', async () => {
      const { logS3SdkErrorResponsePreview } = loadReal();
      const spy = jest.spyOn(console, 'error').mockImplementation(() => {});
      try {
        let calls = 0;
        const body = {
          getReader() {
            return {
              async read() {
                calls += 1;
                if (calls === 1) {
                  return { done: false, value: Buffer.from('web-body') };
                }
                return { done: true, value: undefined };
              },
            };
          },
        };
        await logS3SdkErrorResponsePreview({ $response: { body } });
        const printed = spy.mock.calls.map((args) => args.join(' ')).join('\n');
        expect(printed).toMatch(/web-body/);
      } finally {
        spy.mockRestore();
      }
    });

    test('handles missing $response.body', async () => {
      const { logS3SdkErrorResponsePreview } = loadReal();
      const spy = jest.spyOn(console, 'error').mockImplementation(() => {});
      try {
        await logS3SdkErrorResponsePreview({ $response: { body: null } });
        const printed = spy.mock.calls.map((args) => args.join(' ')).join('\n');
        expect(printed).toMatch(/No \$response\.body/);
      } finally {
        spy.mockRestore();
      }
    });

    test('handles unknown body type', async () => {
      const { logS3SdkErrorResponsePreview } = loadReal();
      const spy = jest.spyOn(console, 'error').mockImplementation(() => {});
      try {
        const body = { weird: true };
        await logS3SdkErrorResponsePreview({ $response: { body } });
        const printed = spy.mock.calls.map((args) => args.join(' ')).join('\n');
        expect(printed).toMatch(/Unknown \$response\.body/);
      } finally {
        spy.mockRestore();
      }
    });

    test('catches exceptions while reading body', async () => {
      const { logS3SdkErrorResponsePreview } = loadReal();
      const spy = jest.spyOn(console, 'error').mockImplementation(() => {});
      try {
        const body = {
          async text() {
            throw new Error('read-fail');
          },
        };
        await logS3SdkErrorResponsePreview({ $response: { body } });
        const printed = spy.mock.calls.map((args) => args.join(' ')).join('\n');
        expect(printed).toMatch(/Could not read error response body/);
      } finally {
        spy.mockRestore();
      }
    });

    test('reports empty body preview when text() returns ""', async () => {
      const { logS3SdkErrorResponsePreview } = loadReal();
      const spy = jest.spyOn(console, 'error').mockImplementation(() => {});
      try {
        const body = { async text() { return ''; } };
        await logS3SdkErrorResponsePreview({
          $response: { body, statusCode: 502 },
        });
        const printed = spy.mock.calls.map((args) => args.join(' ')).join('\n');
        expect(printed).toMatch(/Raw HTTP body is empty/);
        expect(printed).toMatch(/HTTP status:/);
      } finally {
        spy.mockRestore();
      }
    });
  });

  describe('HeadBucket bootstrap (setImmediate)', () => {
    const flushSetImmediate = () =>
      new Promise((resolve) => setImmediate(resolve));

    test('logs API-port hint when MinIO rejects the URL as console port', async () => {
      // Use a non-console port (9000) so the synchronous `warnIfMinio…`
      // doesn't fire — leaving only the catch-block warning we want to
      // assert on. The error itself signals the API-port mismatch.
      process.env.MINIO_ENDPOINT = 'http://127.0.0.1:9000';
      process.env.MINIO_BUCKET = 'darbak';
      const warn = jest.spyOn(console, 'warn').mockImplementation(() => {});
      try {
        loadReal();
        // jest.resetModules() inside loadReal causes the @aws-sdk/client-s3
        // mock factory to run again, producing a NEW jest.fn for `send`.
        // Acquire that fresh reference *after* loadReal but *before* the
        // setImmediate microtask drains.
        const { __send } = require('@aws-sdk/client-s3');
        __send.mockImplementationOnce(async () => {
          const err = new Error('S3 API Requests must be made to API port.');
          err.Code = 'InvalidArgument';
          throw err;
        });
        await flushSetImmediate();
        await flushSetImmediate();
        await flushSetImmediate();
        const printed = warn.mock.calls.map((args) => args.join(' ')).join('\n');
        expect(printed).toMatch(/MinIO rejected this URL as the \*console\* port/);
      } finally {
        warn.mockRestore();
      }
    });

    test('logs 404-hint when HeadBucket returns httpStatusCode=404', async () => {
      process.env.MINIO_ENDPOINT = 'http://127.0.0.1:9000';
      process.env.MINIO_BUCKET = 'darbak';
      const warn = jest.spyOn(console, 'warn').mockImplementation(() => {});
      try {
        loadReal();
        const { __send } = require('@aws-sdk/client-s3');
        __send.mockImplementationOnce(async () => {
          const err = new Error('Not Found');
          err.$metadata = { httpStatusCode: 404 };
          throw err;
        });
        await flushSetImmediate();
        await flushSetImmediate();
        await flushSetImmediate();
        const printed = warn.mock.calls.map((args) => args.join(' ')).join('\n');
        expect(printed).toMatch(/404 \+ plain body usually means/);
      } finally {
        warn.mockRestore();
      }
    });

    test('logs generic HeadBucket failure for unknown errors', async () => {
      process.env.MINIO_ENDPOINT = 'http://127.0.0.1:9000';
      process.env.MINIO_BUCKET = 'darbak';
      const warn = jest.spyOn(console, 'warn').mockImplementation(() => {});
      try {
        loadReal();
        const { __send } = require('@aws-sdk/client-s3');
        __send.mockImplementationOnce(async () => {
          const err = new Error('connection-refused');
          err.name = 'NetworkError';
          throw err;
        });
        await flushSetImmediate();
        await flushSetImmediate();
        await flushSetImmediate();
        const printed = warn.mock.calls.map((args) => args.join(' ')).join('\n');
        expect(printed).toMatch(/HeadBucket failed:/);
        expect(printed).toMatch(/connection-refused/);
      } finally {
        warn.mockRestore();
      }
    });
  });

  describe('warnIfMinioEndpointLooksLikeConsole + module init warnings', () => {
    test('warns when MINIO endpoint port matches a known console port', () => {
      process.env.MINIO_ENDPOINT = '127.0.0.1:9101';
      const spy = jest.spyOn(console, 'warn').mockImplementation(() => {});
      try {
        loadReal();
        const printed = spy.mock.calls.map((args) => args.join(' ')).join('\n');
        expect(printed).toMatch(/MinIO \*console\*/);
      } finally {
        spy.mockRestore();
      }
    });

    test('warns when bucket is set but endpoint is missing (falls back to real AWS)', () => {
      delete process.env.MINIO_ENDPOINT;
      process.env.MINIO_BUCKET = 'darbak';
      const spy = jest.spyOn(console, 'warn').mockImplementation(() => {});
      try {
        loadReal();
        const printed = spy.mock.calls.map((args) => args.join(' ')).join('\n');
        expect(printed).toMatch(/MINIO_ENDPOINT is missing/);
      } finally {
        spy.mockRestore();
      }
    });
  });

  describe('multer upload key generators', () => {
    test('upload builds correct prefix for each fieldname', () => {
      process.env.MINIO_BUCKET = 'darbak';
      loadReal();
      const multer = require('multer');
      // The first multer({...}) call is `upload`.
      const opts = multer.mock.calls[0][0];
      const keyer = opts.storage.key;
      const captured = [];
      const cb = (_e, k) => captured.push(k);

      keyer({ body: { role: 'driver' } }, { fieldname: 'document', originalname: 'My license.pdf' }, cb);
      keyer({ body: { role: 'shipper' } }, { fieldname: 'document', originalname: 'CR.pdf' }, cb);
      keyer({ body: {} }, { fieldname: 'epodPhoto', originalname: 'pic.jpg' }, cb);
      keyer({ body: {} }, { fieldname: 'truckInsurance', originalname: 'ins.pdf' }, cb);
      keyer({ body: {} }, { fieldname: 'insurance', originalname: 'ins.pdf' }, cb);
      keyer({ body: {} }, { fieldname: 'operatingCard', originalname: 'card.pdf' }, cb);
      keyer({ body: {} }, { fieldname: 'anythingElse', originalname: 'misc.bin' }, cb);

      expect(captured[0]).toMatch(/^licenses\//);
      expect(captured[1]).toMatch(/^commercial_docs\//);
      expect(captured[2]).toMatch(/^epod\//);
      expect(captured[3]).toMatch(/^vehicle_insurance\//);
      expect(captured[4]).toMatch(/^vehicle_insurance\//);
      expect(captured[5]).toMatch(/^drivers\/operating-cards\//);
      expect(captured[6]).toMatch(/^others\//);

      const metadataFn = opts.storage.metadata;
      const metaCb = jest.fn();
      metadataFn({}, { fieldname: 'document' }, metaCb);
      expect(metaCb).toHaveBeenCalledWith(null, { fieldName: 'document' });
    });

    test('upload fileFilter accepts allowed image and rejects others', () => {
      loadReal();
      const multer = require('multer');
      const filter = multer.mock.calls[0][0].fileFilter;
      const accept = jest.fn();
      filter(
        {},
        { originalname: 'photo.jpg', mimetype: 'image/jpeg' },
        accept,
      );
      expect(accept).toHaveBeenCalledWith(null, true);

      const reject = jest.fn();
      filter(
        {},
        { originalname: 'evil.exe', mimetype: 'application/x-msdownload' },
        reject,
      );
      expect(reject).toHaveBeenCalledWith(expect.any(Error));
    });

    test('profileImageUpload key requires authenticated user', () => {
      loadReal();
      const multer = require('multer');
      // Second multer() call is profileImageUpload.
      const profileOpts = multer.mock.calls[1][0];
      const keyer = profileOpts.storage.key;
      const ok = jest.fn();
      keyer({ user: { id: 5 } }, {}, ok);
      expect(ok).toHaveBeenCalledWith(null, expect.stringMatching(/^profile\/5\//));

      const err = jest.fn();
      keyer({ user: null }, {}, err);
      expect(err).toHaveBeenCalledWith(expect.any(Error));
    });

    test('profileImageUpload fileFilter accepts/rejects per content type', () => {
      loadReal();
      const multer = require('multer');
      const filter = multer.mock.calls[1][0].fileFilter;
      const ok = jest.fn();
      filter({}, { originalname: 'a.png', mimetype: 'image/png' }, ok);
      expect(ok).toHaveBeenCalledWith(null, true);

      const bad = jest.fn();
      filter({}, { originalname: 'a.heic', mimetype: 'image/heic' }, bad);
      expect(bad).toHaveBeenCalledWith(expect.any(Error));
    });

    test('profileImageUpload metadata embeds the user id', () => {
      loadReal();
      const multer = require('multer');
      const profileOpts = multer.mock.calls[1][0];
      const meta = profileOpts.storage.metadata;
      const cb = jest.fn();
      meta(
        { user: { id: 9 } },
        { fieldname: 'image' },
        cb,
      );
      expect(cb).toHaveBeenCalledWith(null, {
        fieldName: 'image',
        userId: '9',
      });

      const cb2 = jest.fn();
      meta({}, { fieldname: 'image' }, cb2);
      expect(cb2).toHaveBeenCalledWith(null, {
        fieldName: 'image',
        userId: '',
      });
    });

    test('chatMediaUpload key requires userId and shipmentId', () => {
      loadReal();
      const multer = require('multer');
      const chatOpts = multer.mock.calls[2][0];
      const keyer = chatOpts.storage.key;

      const ok = jest.fn();
      keyer(
        { user: { id: 7 }, params: { shipmentId: '12' } },
        { originalname: 'snap.png' },
        ok,
      );
      expect(ok).toHaveBeenCalledWith(
        null,
        expect.stringMatching(/^chat\/12\/7\//),
      );

      const err = jest.fn();
      keyer({ user: null, params: {} }, { originalname: 'a.png' }, err);
      expect(err).toHaveBeenCalledWith(expect.any(Error));
    });

    test('chatMediaUpload fileFilter accepts video, rejects pdf', () => {
      loadReal();
      const multer = require('multer');
      const filter = multer.mock.calls[2][0].fileFilter;
      const ok = jest.fn();
      filter({}, { originalname: 'clip.mp4', mimetype: 'video/mp4' }, ok);
      expect(ok).toHaveBeenCalledWith(null, true);

      const bad = jest.fn();
      filter(
        {},
        { originalname: 'doc.pdf', mimetype: 'application/pdf' },
        bad,
      );
      expect(bad).toHaveBeenCalledWith(expect.any(Error));
    });

    test('chatMediaUpload metadata includes user + shipment ids', () => {
      loadReal();
      const multer = require('multer');
      const chatOpts = multer.mock.calls[2][0];
      const meta = chatOpts.storage.metadata;
      const cb = jest.fn();
      meta(
        { user: { id: 7 }, params: { shipmentId: '42' } },
        { fieldname: 'media' },
        cb,
      );
      expect(cb).toHaveBeenCalledWith(null, {
        fieldName: 'media',
        userId: '7',
        shipmentId: '42',
      });
    });
  });
});
