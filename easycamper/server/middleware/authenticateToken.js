'use strict';

const jwt = require('jsonwebtoken');

module.exports = function authenticateToken(req, res, next) {
  // header case-insensitive
  const authHeader =
    req.headers['authorization'] || req.headers['Authorization'];
  if (!authHeader) return res.status(401).json({ error: 'Token mancante' });

  const token = authHeader.startsWith('Bearer ')
    ? authHeader.slice(7).trim()
    : authHeader.trim();

  if (!token) return res.status(401).json({ error: 'Token mancante' });

  try {
    const secret  = process.env.JWT_SECRET || 'secret'; // fallback nei test
    const payload = jwt.verify(token, secret);

    // ⚠️ uniforma l’id a stringa così combacia con le FK UUID
    req.user = { ...payload, id: String(payload.id) };

    next();
  } catch (err) {
    console.error('❌ JWT non valido:', err);
    return res.status(401).json({ error: 'Token non valido' });
  }
};