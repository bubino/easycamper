// index.js
require('dotenv').config();

const express             = require('express');
const helmet              = require('helmet');
const cors                = require('cors');
const rateLimit           = require('express-rate-limit');
const cookieParser        = require('cookie-parser');
const jwt                 = require('jsonwebtoken');
const bcrypt              = require('bcrypt');
const swaggerUi           = require('swagger-ui-express');
const swaggerSpec         = require('./swagger');
const { body, param, query, validationResult } = require('express-validator');
const { UniqueConstraintError } = require('sequelize');

// import di sequelize e dei modelli
const { sequelize, User, Vehicle, Spot, MaintenanceEntry } = require('./models');

////////////////////////////////////////////////////////////////////////////////
// Helpers
////////////////////////////////////////////////////////////////////////////////
function asyncHandler(fn) {
  return (req, res, next) => Promise.resolve(fn(req, res, next)).catch(next);
}

function validate(req, res, next) {
  const errs = validationResult(req);
  if (!errs.isEmpty()) {
    return res.status(400).json({
      errors: errs.array().map(e => ({ field: e.param, msg: e.msg }))
    });
  }
  next();
}

function authenticateToken(req, res, next) {
  const auth = req.headers.authorization;
  if (!auth?.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Token mancante' });
  }
  jwt.verify(auth.slice(7), process.env.JWT_SECRET, (err, payload) => {
    if (err) return res.status(403).json({ error: 'Token non valido' });
    req.user = payload;
    next();
  });
}

////////////////////////////////////////////////////////////////////////////////
// Setup Express & security middleware
////////////////////////////////////////////////////////////////////////////////
const app = express();
app.use(cookieParser());
app.use(express.json());
app.use(helmet());
app.use(cors({
  origin:   process.env.CORS_ORIGIN,
  methods:  ['GET','POST','PUT','DELETE','OPTIONS'],
  allowedHeaders: ['Content-Type','Authorization']
}));
app.use(rateLimit({
  windowMs: 15*60*1000,
  max:      100,
  standardHeaders: true,
  legacyHeaders:    false
}));

// healthcheck
app.get('/', (_req, res) => res.send('Easycamper API is running'));

// swagger UI
app.use('/docs', swaggerUi.serve, swaggerUi.setup(swaggerSpec));

////////////////////////////////////////////////////////////////////////////////
// AUTH ROUTES
////////////////////////////////////////////////////////////////////////////////
app.post('/auth/register',
  [ body('id').isString().notEmpty(),
    body('username').isString().notEmpty(),
    body('password').isString().isLength({ min: 6 }) ],
  validate, asyncHandler(async (req, res) => {
    const { id, username, password } = req.body;
    const hash = await bcrypt.hash(password, 10);
    try {
      const u = await User.create({ id, username, passwordHash: hash });
      res.status(201).json({ id: u.id, username: u.username });
    } catch (err) {
      if (err instanceof UniqueConstraintError) {
        return res.status(400).json({ error: 'ID o username già esistente' });
      }
      throw err;
    }
  })
);

app.post('/auth/login',
  [ body('username').isString().notEmpty(),
    body('password').isString().notEmpty() ],
  validate, asyncHandler(async (req, res) => {
    const { username, password } = req.body;
    const user = await User.findOne({ where: { username } });
    if (!user || !(await bcrypt.compare(password, user.passwordHash))) {
      return res.status(401).json({ error: 'Credenziali non valide' });
    }
    const accessToken = jwt.sign(
      { userId: user.id, username: user.username },
      process.env.JWT_SECRET,
      { expiresIn: process.env.JWT_EXPIRES_IN }
    );
    const refreshToken = jwt.sign(
      { userId: user.id },
      process.env.JWT_REFRESH_SECRET,
      { expiresIn: process.env.JWT_REFRESH_EXPIRES_IN }
    );
    res.cookie('refreshToken', refreshToken, {
      httpOnly: true,
      secure:   process.env.NODE_ENV === 'production',
      maxAge:   7*24*60*60*1000
    });
    res.json({ accessToken });
  })
);

app.post('/auth/refresh', (req, res) => {
  const token = req.cookies.refreshToken;
  if (!token) return res.status(401).json({ error: 'Refresh token mancante' });
  jwt.verify(token, process.env.JWT_REFRESH_SECRET, (err, payload) => {
    if (err) return res.status(403).json({ error: 'Refresh token non valido' });
    const accessToken = jwt.sign(
      { userId: payload.userId },
      process.env.JWT_SECRET,
      { expiresIn: process.env.JWT_EXPIRES_IN }
    );
    res.json({ accessToken });
  });
});

app.post('/auth/logout', (req, res) => {
  res.clearCookie('refreshToken');
  res.status(204).end();
});

////////////////////////////////////////////////////////////////////////////////
// CRUD /vehicles
////////////////////////////////////////////////////////////////////////////////
app.get('/vehicles',
  authenticateToken,
  asyncHandler(async (req, res) => {
    const list = await Vehicle.findAll({ where: { userId: req.user.userId } });
    res.json(list);
  })
);

app.post('/vehicles',
  authenticateToken,
  [ body('id').isString().notEmpty(),
    body('type').isIn(['camper','van','motorhome']),
    body('make').isString().notEmpty(),
    body('model').isString().notEmpty() ],
  validate, asyncHandler(async (req, res) => {
    req.body.userId = req.user.userId;
    const v = await Vehicle.create(req.body);
    res.status(201).json(v);
  })
);

app.get('/vehicles/:id',
  authenticateToken,
  [ param('id').isString().notEmpty() ], validate,
  asyncHandler(async (req, res) => {
    const v = await Vehicle.findOne({
      where: { id: req.params.id, userId: req.user.userId }
    });
    if (!v) return res.status(404).json({ error: 'Vehicle non trovato' });
    res.json(v);
  })
);

app.put('/vehicles/:id',
  authenticateToken,
  [ param('id').isString().notEmpty() ], validate,
  asyncHandler(async (req, res) => {
    const [updated] = await Vehicle.update(req.body, {
      where: { id: req.params.id, userId: req.user.userId }
    });
    if (!updated) return res.status(404).json({ error: 'Vehicle non trovato' });
    const v = await Vehicle.findByPk(req.params.id);
    res.json(v);
  })
);

app.delete('/vehicles/:id',
  authenticateToken,
  [ param('id').isString().notEmpty() ], validate,
  asyncHandler(async (req, res) => {
    const d = await Vehicle.destroy({
      where: { id: req.params.id, userId: req.user.userId }
    });
    if (!d) return res.status(404).json({ error: 'Vehicle non trovato' });
    res.status(204).end();
  })
);

////////////////////////////////////////////////////////////////////////////////
// CRUD /spots
////////////////////////////////////////////////////////////////////////////////
app.get('/spots',
  authenticateToken,
  asyncHandler(async (req, res) => {
    const list = await Spot.findAll({ where: { userId: req.user.userId } });
    res.json(list);
  })
);

app.post('/spots',
  authenticateToken,
  [ body('id').isString().notEmpty(),
    body('name').isString().notEmpty(),
    body('description').optional().isString(),
    body('latitude').isFloat({ min: -90, max: 90 }),
    body('longitude').isFloat({ min: -180, max: 180 }) ],
  validate, asyncHandler(async (req, res) => {
    req.body.userId = req.user.userId;
    const s = await Spot.create(req.body);
    res.status(201).json(s);
  })
);

app.get('/spots/:id',
  authenticateToken,
  [ param('id').isString().notEmpty() ], validate,
  asyncHandler(async (req, res) => {
    const s = await Spot.findOne({
      where: { id: req.params.id, userId: req.user.userId }
    });
    if (!s) return res.status(404).json({ error: 'Spot non trovato' });
    res.json(s);
  })
);

app.put('/spots/:id',
  authenticateToken,
  [ param('id').isString().notEmpty() ], validate,
  asyncHandler(async (req, res) => {
    const [u] = await Spot.update(req.body, {
      where: { id: req.params.id, userId: req.user.userId }
    });
    if (!u) return res.status(404).json({ error: 'Spot non trovato' });
    const s = await Spot.findByPk(req.params.id);
    res.json(s);
  })
);

app.delete('/spots/:id',
  authenticateToken,
  [ param('id').isString().notEmpty() ], validate,
  asyncHandler(async (req, res) => {
    const d = await Spot.destroy({
      where: { id: req.params.id, userId: req.user.userId }
    });
    if (!d) return res.status(404).json({ error: 'Spot non trovato' });
    res.status(204).end();
  })
);

////////////////////////////////////////////////////////////////////////////////
// CRUD /maintenance
////////////////////////////////////////////////////////////////////////////////
app.get('/maintenance',
  authenticateToken,
  [ query('vehicleId').optional().isString() ],
  validate, asyncHandler(async (req, res) => {
    const where = {};
    if (req.query.vehicleId) where.vehicleId = req.query.vehicleId;
    const list = await MaintenanceEntry.findAll({
      where,
      include: [{
        model: Vehicle,
        as: 'vehicle',
        where: { userId: req.user.userId },
        attributes: ['id','make','model']
      }]
    });
    res.json(list);
  })
);

app.post('/maintenance',
  authenticateToken,
  [ body('id').isString().notEmpty(),
    body('vehicleId').isString().notEmpty(),
    body('date').isISO8601(),
    body('type').isIn(['tagliando','riparazione','controllo']),
    body('notes').optional().isString() ],
  validate, asyncHandler(async (req, res) => {
    const vehicle = await Vehicle.findOne({
      where: { id: req.body.vehicleId, userId: req.user.userId }
    });
    if (!vehicle) return res.status(403).json({ error: 'Veicolo non autorizzato' });
    const m = await MaintenanceEntry.create(req.body);
    res.status(201).json(m);
  })
);

app.get('/maintenance/:id',
  authenticateToken,
  [ param('id').isString().notEmpty() ], validate,
  asyncHandler(async (req, res) => {
    const e = await MaintenanceEntry.findByPk(req.params.id, {
      include: [{
        model: Vehicle,
        as: 'vehicle',
        where: { userId: req.user.userId },
        attributes: ['id','make','model']
      }]
    });
    if (!e) return res.status(404).json({ error: 'Entry non trovata o non autorizzata' });
    res.json(e);
  })
);

app.put('/maintenance/:id',
  authenticateToken,
  [ param('id').isString().notEmpty() ], validate,
  asyncHandler(async (req, res) => {
    const entry = await MaintenanceEntry.findByPk(req.params.id, {
      include: [{ model: Vehicle, as: 'vehicle', where: { userId: req.user.userId } }]
    });
    if (!entry) return res.status(404).json({ error: 'Entry non trovata o non autorizzata' });
    await entry.update(req.body);
    res.json(entry);
  })
);

app.delete('/maintenance/:id',
  authenticateToken,
  [ param('id').isString().notEmpty() ], validate,
  asyncHandler(async (req, res) => {
    const entry = await MaintenanceEntry.findByPk(req.params.id, {
      include: [{ model: Vehicle, as: 'vehicle', where: { userId: req.user.userId } }]
    });
    if (!entry) return res.status(404).json({ error: 'Entry non trovata o non autorizzata' });
    await entry.destroy();
    res.status(204).end();
  })
);

////////////////////////////////////////////////////////////////////////////////
// Error handler
////////////////////////////////////////////////////////////////////////////////
app.use((err, _req, res, _next) => {
  console.error(err.stack);
  res.status(500).json({ error: 'Server error' });
});

////////////////////////////////////////////////////////////////////////////////
// export per Supertest
////////////////////////////////////////////////////////////////////////////////
module.exports = app;

////////////////////////////////////////////////////////////////////////////////
// se avviato direttamente, facci partire sync() + listen()
////////////////////////////////////////////////////////////////////////////////
if (require.main === module) {
  sequelize.sync({ alter: true })
    .then(() => {
      const port = process.env.PORT || 3000;
      app.listen(port, () => {
        console.log(`Server listening on http://localhost:${port}`);
      });
    })
    .catch(err => {
      console.error('Sync error:', err);
      process.exit(1);
    });
}
