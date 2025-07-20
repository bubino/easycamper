// routes/auth.js
'use strict';
const express    = require('express');
const router     = express.Router();
const bcrypt     = require('bcrypt');
const jwt        = require('jsonwebtoken');
const crypto = require('crypto');
const nodemailer = require('nodemailer');
const { User, RefreshToken, AuditLog } = require('../models');
const { sendVerificationEmail, sendResetPasswordEmail } = require('./email');

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

// Registrazione utente (PRODUZIONE)
router.post('/register', async (req, res) => {
  const { username, email, password } = req.body;
  try {
    const user = await User.create({ username, email, password });
    // Genera token di verifica
    const verificationToken = jwt.sign({ id: user.id }, process.env.JWT_SECRET || 'testsecret', { expiresIn: '1d' });
    await sendVerificationEmail(user, verificationToken);
    res.status(201).json({ id: user.id, username: user.username, email: user.email, message: 'Verifica la tua email per attivare l’account.' });
  } catch (err) {
    console.error('Errore registrazione:', err.message, err.errors);
    res.status(400).json({ error: err.message, details: err.errors });
  }
});

// Endpoint verifica email
router.get('/verify-email', async (req, res) => {
  const { token } = req.query;
  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET || 'testsecret');
    const user = await User.findByPk(decoded.id);
    if (!user) return res.status(404).json({ error: 'User non trovato' });
    user.emailVerified = true;
    await user.save();
    res.json({ message: 'Email verificata! Ora puoi accedere.' });
  } catch (err) {
    res.status(400).json({ error: 'Token non valido o scaduto.' });
  }
});

// Login utente (multi-device, refresh token)
router.post('/login', async (req, res) => {
  const { email, password } = req.body;
  try {
    const user = await User.findOne({ where: { email } });
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }
    if (!user.emailVerified) {
      return res.status(403).json({ error: 'Email non verificata. Controlla la tua casella di posta.' });
    }
    const valid = await user.validatePassword(password);
    if (!valid) {
      return res.status(401).json({ error: 'Invalid password' });
    }
    // Genera JWT e Refresh Token
    const token = jwt.sign({ id: user.id }, process.env.JWT_SECRET || 'testsecret', { expiresIn: '15m' });
    const refreshToken = jwt.sign({ id: user.id }, process.env.REFRESH_TOKEN_SECRET || 'refreshsecret', { expiresIn: '7d' });
    // Salva il refresh token hashato nella tabella multi-device
    await RefreshToken.create({
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
    // Notifica all'utente (mock: console.log)
    console.log(`Notifica: nuovo login per utente ${user.email} da device ${getDeviceInfo(req)} IP ${req.ip}`);
    // Limite: massimo 2 device attivi per utente
    const tokens = await RefreshToken.findAll({
      where: { userId: user.id },
      order: [['createdAt', 'ASC']]
    });
    if (tokens.length > 2) {
      // Elimina il token più vecchio
      await tokens[0].destroy();
    }
    res.cookie('refreshToken', refreshToken, { httpOnly: true, sameSite: 'strict', secure: process.env.NODE_ENV === 'production' });
    res.status(200).json({ message: 'Login successful', userId: user.id, token });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Refresh token (rotazione, multi-device)
router.post('/refresh', async (req, res) => {
  const { refreshToken } = req.cookies;
  if (!refreshToken) {
    return res.status(401).send('Refresh token non trovato');
  }
  try {
    const decoded = jwt.verify(refreshToken, process.env.REFRESH_TOKEN_SECRET || 'refreshsecret');
    const user = await User.findByPk(decoded.id);
    if (!user) {
      return res.status(403).send('Refresh token non valido');
    }
    const tokenHash = hashToken(refreshToken);
    const dbToken = await RefreshToken.findOne({ where: { userId: user.id, tokenHash } });
    if (!dbToken) {
      return res.status(403).send('Refresh token non valido');
    }
    // Rotazione: elimina il vecchio token e crea uno nuovo
    await dbToken.destroy();
    const newRefreshToken = jwt.sign({ id: user.id }, process.env.REFRESH_TOKEN_SECRET || 'refreshsecret', { expiresIn: '7d' });
    await RefreshToken.create({
      userId: user.id,
      tokenHash: hashToken(newRefreshToken),
      deviceInfo: getDeviceInfo(req),
      ip: req.ip || req.connection.remoteAddress || '',
      fingerprint: getFingerprint(req),
      createdAt: new Date(),
      expiresAt: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000)
    });
    res.cookie('refreshToken', newRefreshToken, { httpOnly: true, sameSite: 'strict', secure: process.env.NODE_ENV === 'production' });
    const token = jwt.sign({ id: user.id }, process.env.JWT_SECRET || 'testsecret', { expiresIn: '15m' });
    res.json({ token });
  } catch (err) {
    return res.status(403).send('Refresh token non valido');
  }
});

// Logout (multi-device, elimina solo il token usato)
router.post('/logout', async (req, res) => {
  const { refreshToken } = req.cookies;
  // Audit log: logout
  if (refreshToken) {
    try {
      const decoded = jwt.decode(refreshToken);
      if (decoded && decoded.id) {
        await AuditLog.create({
          userId: decoded.id,
          operation: 'logout',
          deviceInfo: getDeviceInfo(req),
          ip: req.ip || req.connection.remoteAddress || '',
          createdAt: new Date()
        });
        // Notifica all'utente (mock: console.log)
        console.log(`Notifica: logout per utente ${decoded.id} da device ${getDeviceInfo(req)} IP ${req.ip}`);
      }
    } catch (err) {}
  }
  if (refreshToken) {
    try {
      const decoded = jwt.decode(refreshToken);
      if (decoded && decoded.id) {
        const tokenHash = hashToken(refreshToken);
        await RefreshToken.destroy({ where: { userId: decoded.id, tokenHash } });
      }
    } catch (err) {
      // ignora errori se il token è malformato
    }
  }
  res.clearCookie('refreshToken');
  res.status(200).send('Logout effettuato con successo');
});

// Modifica profilo utente (PRODUZIONE)
router.put('/profile', async (req, res) => {
  const { email, name } = req.body;
  try {
    const user = await User.findOne({ where: { email } });
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }
    user.name = name;
    await user.save();
    res.status(200).json({ message: 'Profile updated', name: user.name });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Elenco device attivi per utente
router.get('/devices', async (req, res) => {
  // Recupera userId dal JWT
  const authHeader = req.headers['authorization'];
  if (!authHeader) return res.status(401).json({ error: 'Token mancante' });
  const token = authHeader.replace('Bearer ', '');
  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET || 'testsecret');
    const tokens = await RefreshToken.findAll({
      where: { userId: decoded.id },
      attributes: ['id', 'deviceInfo', 'createdAt', 'expiresAt']
    });
    res.json({ devices: tokens });
  } catch (err) {
    res.status(401).json({ error: 'Token non valido' });
  }
});

// Revoca manuale di un device (refresh token)
router.delete('/devices/:id', async (req, res) => {
  // Recupera userId dal JWT
  const authHeader = req.headers['authorization'];
  if (!authHeader) return res.status(401).json({ error: 'Token mancante' });
  const token = authHeader.replace('Bearer ', '');
  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET || 'testsecret');
    const deviceId = req.params.id;
    const deleted = await RefreshToken.destroy({ where: { id: deviceId, userId: decoded.id } });
    if (deleted) {
      // Audit log: revoca device
      await AuditLog.create({
        userId: decoded.id,
        operation: 'revoke_device',
        deviceInfo: req.params.id,
        ip: req.ip || req.connection.remoteAddress || '',
        createdAt: new Date()
      });
      // Notifica all'utente (mock: console.log)
      console.log(`Notifica: device revocato per utente ${decoded.id} deviceId ${req.params.id} IP ${req.ip}`);
      res.json({ message: 'Device revocato' });
    } else {
      res.status(404).json({ error: 'Device non trovato' });
    }
  } catch (err) {
    res.status(401).json({ error: 'Token non valido' });
  }
});

// Richiesta reset password
router.post('/request-reset-password', async (req, res) => {
  const { email } = req.body;
  try {
    const user = await User.findOne({ where: { email } });
    if (!user) return res.status(404).json({ error: 'User non trovato' });
    // Genera token reset valido 1h
    const resetToken = jwt.sign({ id: user.id }, process.env.JWT_SECRET || 'testsecret', { expiresIn: '1h' });
    await sendResetPasswordEmail(user, resetToken);
    res.json({ message: 'Email di reset inviata. Controlla la tua casella di posta.' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Endpoint reset password
router.post('/reset-password', async (req, res) => {
  const { token, newPassword } = req.body;
  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET || 'testsecret');
    const user = await User.findByPk(decoded.id);
    if (!user) return res.status(404).json({ error: 'User non trovato' });
    user.password = newPassword;
    await user.save();
    res.json({ message: 'Password aggiornata con successo.' });
  } catch (err) {
    res.status(400).json({ error: 'Token non valido o scaduto.' });
  }
});

module.exports = router;
