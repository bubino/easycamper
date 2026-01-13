// server/routes/users.js
const express = require('express');
const router  = express.Router();
const { User, AuditLog } = require('../models');
const crypto = require('crypto');
const rateLimit = require('express-rate-limit');

// Funzione helper per rimuovere campi sensibili dall'oggetto utente prima di rispondere
function sanitizeUser(userInstance) {
  if (!userInstance) return userInstance;
  const user = userInstance.toJSON ? userInstance.toJSON() : { ...userInstance };
  delete user.passwordHash;
  delete user.refreshTokens;
  delete user.emailChangeToken;
  delete user.emailChangeNew;
  delete user.emailChangeRequestedAt;
  return user;
}

const sensitiveLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minuti
  max: 5, // max 5 richieste per 15 minuti
  message: { error: 'Troppe richieste, riprova più tardi.' },
  skip: (req) => process.env.NODE_ENV === 'test'
});

// Validazione base dell'input per creazione/aggiornamento utente
function validateUserPayload(body, { forUpdate = false } = {}) {
  const errors = [];
  if (!forUpdate) {
    if (!body || (!body.email && !body.username)) {
      errors.push('Email o username obbligatori');
    }
    if (!body.password && !body.passwordHash) {
      errors.push('Password obbligatoria');
    }
  }
  // Qui potremmo aggiungere ulteriori regole in base allo schema User (es. formato email)
  return errors;
}

// Helper: accetta UUID (standard) o numerico legacy
function isValidUserId(id) {
  const s = String(id);
  // UUID v4-ish (accetta anche altre versioni, basta formato)
  const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
  const numeric = /^[0-9]+$/;
  return uuid.test(s) || numeric.test(s);
}

// POST /users
router.post('/', async (req, res, next) => {
  try {
    const errors = validateUserPayload(req.body, { forUpdate: false });
    if (errors.length) {
      return res.status(400).json({ error: errors.join(', ') });
    }

    const user = await User.create(req.body);
    res.status(201).json(sanitizeUser(user));
  } catch (err) {
    next(err);
  }
});

// GET /users
router.get('/', async (_req, res, next) => {
  try {
    const users = await User.findAll();
    res.json(users.map(sanitizeUser));
  } catch (err) {
    next(err);
  }
});

// GET /users/confirm-email-change?token=...
router.get('/confirm-email-change', sensitiveLimiter, async (req, res, next) => {
  try {
    const { token } = req.query;
    if (!token) {
      return res.status(400).json({ error: 'Token mancante' });
    }
    const user = await User.findOne({ where: { emailChangeToken: token } });
    if (!user || !user.emailChangeNew) {
      return res.status(400).json({ error: 'Token non valido o già usato' });
    }
    const maxAgeMs = 24 * 60 * 60 * 1000;
    if (user.emailChangeRequestedAt && (Date.now() - user.emailChangeRequestedAt.getTime() > maxAgeMs)) {
      // Token scaduto: opzionalmente lo azzero per evitare riuso confuso
      user.emailChangeToken = null;
      user.emailChangeNew = null;
      user.emailChangeRequestedAt = null;
      await user.save();
      return res.status(400).json({ error: 'Token scaduto' });
    }
    const oldEmail = user.email;
    user.email = user.emailChangeNew;
    // Mark new email as unverified
    user.emailVerified = false;
    // Audit log: cambio email
    await AuditLog.create({
      userId: user.id,
      operation: 'change_email',
      ip: req.ip || req.connection.remoteAddress || '',
      createdAt: new Date()
    });
    // Notifica email a vecchio e nuovo indirizzo
    // Skip email notification in test environment
    if (process.env.NODE_ENV !== 'test') {
      const { sendEmailChangeNotification } = require('./email');
      await sendEmailChangeNotification({
        oldEmail,
        newEmail: user.email,
        username: user.username || user.email
      });
    }
    user.emailChangeToken = null;
    user.emailChangeNew = null;
    user.emailChangeRequestedAt = null;
    await user.save();
    res.json({ message: 'Cambio email confermato. Effettua il login con la nuova email.' });
  } catch (err) {
    next(err);
  }
});

// GET /users/:id (accetta UUID o numerico)
router.get('/:id', async (req, res, next) => {
  try {
    const id = req.params.id;
    if (!isValidUserId(id)) {
      return res.status(400).json({ error: 'ID non valido' });
    }
    const user = await User.findByPk(id);
    if (!user) return res.status(404).json({ error: 'Not found' });
    res.json(sanitizeUser(user));
  } catch (err) {
    next(err);
  }
});

// PUT /users/:id
router.put('/:id', async (req, res, next) => {
  try {
    const id = req.params.id;
    if (!isValidUserId(id)) {
      return res.status(400).json({ error: 'ID non valido' });
    }

    const errors = validateUserPayload(req.body, { forUpdate: true });
    if (errors.length) {
      return res.status(400).json({ error: errors.join(', ') });
    }

    // Evita modifiche dirette a campi sensibili via PUT generico
    ['passwordHash', 'emailChangeToken', 'emailChangeNew', 'emailChangeRequestedAt'].forEach(field => {
      if (field in req.body) delete req.body[field];
    });

    const [n] = await User.update(req.body, { where: { id } });
    if (!n) return res.status(404).json({ error: 'Not found' });
    const updated = await User.findByPk(id);
    res.json(sanitizeUser(updated));
  } catch (err) {
    next(err);
  }
});

// DELETE /users/:id
router.delete('/:id', async (req, res, next) => {
  try {
    const id = req.params.id;
    if (!isValidUserId(id)) {
      return res.status(400).json({ error: 'ID non valido' });
    }
    const n = await User.destroy({ where: { id } });
    if (!n) return res.status(404).json({ error: 'Not found' });
    res.status(204).end();
  } catch (err) {
    next(err);
  }
});

// POST /users/:id/change-email
router.post('/:id/change-email', sensitiveLimiter, async (req, res, next) => {
  try {
    const id = req.params.id;
    if (!isValidUserId(id)) {
      return res.status(400).json({ error: 'ID non valido' });
    }

    const { newEmail } = req.body;
    if (!newEmail || typeof newEmail !== 'string') {
      return res.status(400).json({ error: 'Nuova email richiesta' });
    }
    const trimmedEmail = newEmail.trim();
    if (!trimmedEmail || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(trimmedEmail)) {
      return res.status(400).json({ error: 'Nuova email non valida' });
    }

    const user = await User.findByPk(id);
    if (!user) return res.status(404).json({ error: 'Utente non trovato' });
    if (user.email && user.email.toLowerCase() === trimmedEmail.toLowerCase()) {
      return res.status(400).json({ error: 'La nuova email coincide con quella attuale' });
    }

    // TODO: opzionale, se l'email deve essere unica nel sistema, controllare qui l'esistenza di altri utenti con la stessa email

    // Genera token sicuro
    const token = crypto.randomBytes(32).toString('hex');
    // Salva token e nuova email in user
    user.emailChangeToken = token;
    user.emailChangeNew = trimmedEmail;
    user.emailChangeRequestedAt = new Date();
    await user.save();
    // Invio email di conferma cambio email al nuovo indirizzo
    if (process.env.NODE_ENV !== 'test') {
      const { sendEmailChangeRequest } = require('./email');
      await sendEmailChangeRequest({
        newEmail: trimmedEmail,
        username: user.username || user.email,
        token
      });
    }
    // Test invio email reale con Mailtrap
    if (process.env.NODE_ENV === 'test-mailtrap') {
      const { sendEmailChangeRequest } = require('./email');
      (async () => {
        await sendEmailChangeRequest({
          newEmail: 'test@mailtrap.io',
          username: 'TestUser',
          token: 'testtoken123'
        });
        console.log('Email inviata a Mailtrap!');
      })();
    }
    // Logga l'operazione in AuditLog
    await AuditLog.create({
      userId: user.id,
      operation: 'request_email_change',
      ip: req.ip || req.connection.remoteAddress || '',
      createdAt: new Date()
    });
    res.json({ message: 'Richiesta cambio email ricevuta. Controlla la nuova casella per confermare.' });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
