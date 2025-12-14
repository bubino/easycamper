const jwt = require('jsonwebtoken');
const crypto = require('crypto');
const { v4: uuidv4 } = require('uuid');
const { RefreshToken, AuditLog } = require('../models');

function hashToken(token) {
  return crypto.createHash('sha256').update(token).digest('hex');
}

function getDeviceInfo(req) {
  return req.headers['user-agent'] || 'unknown';
}

function getFingerprint(req) {
  const userAgent = req.headers['user-agent'] || '';
  const ip = req.ip || req.connection.remoteAddress || '';
  return crypto.createHash('sha256').update(userAgent + ip).digest('hex');
}

async function handleLogin(user, req, accessExpiry = '15m', refreshExpiry = '7d', maxDevices = 2) {
  const token = jwt.sign({ id: user.id }, process.env.JWT_SECRET || 'testsecret', { expiresIn: accessExpiry });
  const refreshToken = jwt.sign({ id: user.id, jti: uuidv4() }, process.env.REFRESH_TOKEN_SECRET || 'refreshsecret', { expiresIn: refreshExpiry });

  // Save refresh token
  await RefreshToken.create({
    id: uuidv4(),
    userId: user.id,
    tokenHash: hashToken(refreshToken),
    deviceInfo: getDeviceInfo(req),
    ip: req.ip || req.connection.remoteAddress || '',
    fingerprint: getFingerprint(req),
    createdAt: new Date(),
    expiresAt: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000)
  });

  // Audit log: login
  await AuditLog.create({
    userId: user.id,
    operation: 'login',
    deviceInfo: getDeviceInfo(req),
    ip: req.ip || req.connection.remoteAddress || '',
    createdAt: new Date()
  });

  // Enforce max devices
  const tokens = await RefreshToken.findAll({ where: { userId: user.id }, order: [['createdAt', 'ASC']] });
  if (tokens.length > maxDevices) {
    await tokens[0].destroy();
  }

  return { token, refreshToken };
}

module.exports = { ...require('../helpers'), handleLogin };