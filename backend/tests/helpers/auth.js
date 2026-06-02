/**
 * Helpers for issuing JWT tokens that match the auth middleware's
 * expectations (`{ id, role }` payload signed with `JWT_SECRET`).
 */
'use strict';

const jwt = require('jsonwebtoken');

const JWT_SECRET = () => process.env.JWT_SECRET || 'test_jwt_secret_do_not_use_in_prod';

const signToken = (payload, options = {}) =>
  jwt.sign(payload, JWT_SECRET(), { expiresIn: '1h', ...options });

const tokenForDriver = (id = 100) => signToken({ id, role: 'driver' });
const tokenForShipper = (id = 200) => signToken({ id, role: 'shipper' });
const tokenForAdmin = (id = 1) => signToken({ id, role: 'admin' });
const expiredToken = (id = 100, role = 'driver') =>
  jwt.sign({ id, role }, JWT_SECRET(), { expiresIn: -10 });
const tokenWithBadSecret = (id = 100, role = 'driver') =>
  jwt.sign({ id, role }, 'wrong_secret');

const authHeader = (token) => ({ Authorization: `Bearer ${token}` });

module.exports = {
  signToken,
  tokenForDriver,
  tokenForShipper,
  tokenForAdmin,
  expiredToken,
  tokenWithBadSecret,
  authHeader,
};
