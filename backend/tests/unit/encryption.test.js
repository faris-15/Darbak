/**
 * Tests for utils/encryption.js
 *
 * The module guards against weak / missing keys at require-time, so these
 * tests cover:
 *   - the happy round-trip (AES-256-CBC determinism with fixed IV)
 *   - that decrypting a non-hex value falls back gracefully
 *   - that null/undefined are passed through
 *   - constructor-time validation: missing key, wrong key length, wrong IV length
 */
'use strict';

describe('utils/encryption', () => {
  describe('round-trip', () => {
    let encryption;

    beforeAll(() => {
      jest.resetModules();
      encryption = require('../../utils/encryption');
    });

    test.each([
      ['simple ASCII', '1023456789'],
      ['Arabic', 'سجل تجاري ١٢٣'],
      ['mixed', 'CR-2024 | شركة الرياض'],
      ['leading zeros', '00099887766'],
      ['emoji', '🚚 driver license'],
      ['long string', 'x'.repeat(512)],
    ])('encrypts/decrypts %s', (_label, plain) => {
      const encrypted = encryption.encryptText(plain);
      expect(encrypted).toMatch(/^[a-f0-9]+$/i);
      expect(encrypted).not.toBe(plain);
      expect(encryption.decryptText(encrypted)).toBe(plain);
    });

    test('encrypting the same plaintext twice with a fixed IV is deterministic', () => {
      const a = encryption.encryptText('repeat-me');
      const b = encryption.encryptText('repeat-me');
      expect(a).toBe(b);
    });

    test('returns null for null/undefined plaintext', () => {
      expect(encryption.encryptText(null)).toBeNull();
      expect(encryption.encryptText(undefined)).toBeNull();
    });

    test('decryptText returns null when input is empty', () => {
      expect(encryption.decryptText(null)).toBeNull();
      expect(encryption.decryptText('')).toBeNull();
    });

    test('decryptText falls back to original value when input is not valid hex', () => {
      // Production code logs a warning and returns the raw string so legacy /
      // un-encrypted rows do not crash callers (see Bid.getBidsByShipment).
      const result = encryption.decryptText('not-encrypted-plain-value');
      expect(typeof result).toBe('string');
      expect(result).toBe('not-encrypted-plain-value');
    });

    test('coerces non-string plaintext via String()', () => {
      const encrypted = encryption.encryptText(12345);
      expect(encryption.decryptText(encrypted)).toBe('12345');
    });
  });

  describe('environment validation', () => {
    let originalKey;
    let originalIv;

    beforeEach(() => {
      originalKey = process.env.ENCRYPTION_KEY;
      originalIv = process.env.ENCRYPTION_IV;
      jest.resetModules();
    });

    afterEach(() => {
      process.env.ENCRYPTION_KEY = originalKey;
      process.env.ENCRYPTION_IV = originalIv;
      jest.resetModules();
    });

    test('throws when ENCRYPTION_KEY is missing', () => {
      delete process.env.ENCRYPTION_KEY;
      expect(() => require('../../utils/encryption')).toThrow(
        /ENCRYPTION_KEY and ENCRYPTION_IV/
      );
    });

    test('throws when ENCRYPTION_IV is missing', () => {
      delete process.env.ENCRYPTION_IV;
      expect(() => require('../../utils/encryption')).toThrow(
        /ENCRYPTION_KEY and ENCRYPTION_IV/
      );
    });

    test('throws when key length is wrong (not 32 bytes)', () => {
      process.env.ENCRYPTION_KEY = 'aabbcc'; // 3 bytes
      expect(() => require('../../utils/encryption')).toThrow(/32-byte hex string/);
    });

    test('throws when IV length is wrong (not 16 bytes)', () => {
      process.env.ENCRYPTION_IV = 'aabb'; // 2 bytes
      expect(() => require('../../utils/encryption')).toThrow(/16-byte hex string/);
    });
  });
});
