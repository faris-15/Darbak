const crypto = require('crypto');

const ENCRYPTION_KEY = process.env.ENCRYPTION_KEY;
const ENCRYPTION_IV = process.env.ENCRYPTION_IV;

if (!ENCRYPTION_KEY || !ENCRYPTION_IV) {
  throw new Error('ENCRYPTION_KEY and ENCRYPTION_IV must be defined in environment variables.');
}

const key = Buffer.from(ENCRYPTION_KEY, 'hex');
const iv = Buffer.from(ENCRYPTION_IV, 'hex');

if (key.length !== 32) {
  throw new Error('ENCRYPTION_KEY must be a 32-byte hex string (64 hex characters).');
}
if (iv.length !== 16) {
  throw new Error('ENCRYPTION_IV must be a 16-byte hex string (32 hex characters).');
}

const encryptText = (plainText) => {
  if (plainText === null || typeof plainText === 'undefined') return null;
  const cipher = crypto.createCipheriv('aes-256-cbc', key, iv);
  let encrypted = cipher.update(String(plainText), 'utf8', 'hex');
  encrypted += cipher.final('hex');
  return encrypted;
};

const decryptText = (encryptedHex) => {
  if (!encryptedHex) return null;
  try {
    const decipher = crypto.createDecipheriv('aes-256-cbc', key, iv);
    let decrypted = decipher.update(String(encryptedHex), 'hex', 'utf8');
    decrypted += decipher.final('utf8');
    return decrypted;
  } catch (error) {
    console.warn('[decryptText] Decryption failed, returning original value:', error.message);
    return String(encryptedHex);
  }
};

module.exports = { encryptText, decryptText };