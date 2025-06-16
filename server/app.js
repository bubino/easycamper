require('dotenv').config({
  path: process.env.NODE_ENV === 'test' ? '.env.test' : '.env'
});

const express        = require('express');
const helmet         = require('helmet');
const cors           = require('cors');
const cookieParser   = require('cookie-parser');
const swaggerUi      = require('swagger-ui-express');
const swaggerSpec    = require('./swagger');

const authenticate   = require('./middleware/authenticateToken');
const specRouter     = require('./routes/camperSpecs');
const uploadsRouter  = require('./routes/uploads');

const app = express();

/* ──────────────  middleware  ────────────── */
app.use(helmet());
app.use(cors({ origin: true, credentials: true }));
app.use(express.json());
app.use(cookieParser());

/* ──────────────  health  ────────────── */
app.get('/health', (_req, res) => res.json({ status: 'ok' }));

/* ──────────────  Swagger  ────────────── */
app.use('/api-docs', swaggerUi.serve, swaggerUi.setup(swaggerSpec));

/* ──────────────  rotte pubbliche  ────────────── */
app.use('/auth', require('./routes/auth'));

/* ──────────────  rotte protette  ────────────── */
app.use('/users',             authenticate, require('./routes/users'));
app.use('/vehicles',          authenticate, require('./routes/vehicles'));
app.use('/spots',             authenticate, require('./routes/spots'));
app.use('/public-spots',      authenticate, require('./routes/publicSpots'));
app.use('/recommended-spots', authenticate, require('./routes/recommendedSpots'));
app.use('/favorites',         authenticate, require('./routes/favorites'));
app.use('/maintenance',       authenticate, require('./routes/maintenanceEntries'));
app.use('/camper-specs',      authenticate, specRouter);

/* ──────────────  upload immagini (MinIO)  ────────────── */
app.use('/api/uploads', uploadsRouter);

/* ──────────────  export  ────────────── */
module.exports = app;