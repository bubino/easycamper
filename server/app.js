// Carica variabili d'ambiente in base a NODE_ENV
const dotenv = require('dotenv');
const envFile = process.env.NODE_ENV === 'test'
  ? '.env.test'
  : process.env.NODE_ENV === 'development'
    ? '.env.development'
    : '.env';
dotenv.config({ path: envFile });

const express      = require('express');
const helmet       = require('helmet');
const cors         = require('cors');
const cookieParser = require('cookie-parser');
const swaggerUi    = require('swagger-ui-express');
const swaggerSpec  = require('./swagger');
const jwt          = require('jsonwebtoken');
const rateLimit    = require('express-rate-limit');
const hpp          = require('hpp');

const authenticate = require('./middleware/authenticateToken');
const specRouter   = require('./routes/camperSpecs');
const uploadsRouter= require('./routes/uploads');
const vehicleModelsRouter = require('./routes/vehicleModels');
// const authTestRouter= require('./routes/auth.test'); // COMMENTATO: solo per test

const app = express();

// In test environment decode token and set req.user before routes
if (process.env.NODE_ENV === 'test') {
  app.use((req, res, next) => {
    const authHeader = req.headers['authorization'] || '';
    const token = authHeader.startsWith('Bearer ') ? authHeader.slice(7).trim() : authHeader.trim();
    try {
      const payload = jwt.decode(token);
      if (payload && payload.id) {
        req.user = { id: String(payload.id) };
      }
    } catch {}
    next();
  });
}

// Ensure req.query is writable to avoid xss-clean errors
app.use((req, res, next) => {
  if (process.env.NODE_ENV !== 'test') {
    try {
      const originalQuery = req.query;
      Object.defineProperty(req, 'query', {
        value: originalQuery,
        writable: true,
        configurable: true
      });
    } catch (e) {
      // ignore
    }
  }
  next();
});

// security middlewares
app.use(helmet());
app.use(cors({ origin: true, credentials: true }));
app.use(express.json());
app.use(cookieParser());
if (process.env.NODE_ENV !== 'test') {
  // Sanitizer custom per req.body: rimuove tag HTML
  function sanitizeInputs(obj) {
    if (typeof obj === 'string') {
      return obj.replace(/<[^>]*>?/gm, '');
    }
    if (Array.isArray(obj)) {
      return obj.map(sanitizeInputs);
    }
    if (obj && typeof obj === 'object') {
      Object.keys(obj).forEach(key => {
        obj[key] = sanitizeInputs(obj[key]);
      });
      return obj;
    }
    return obj;
  }
  app.use((req, res, next) => {
    const methodsWithBody = ['POST', 'PUT', 'PATCH', 'DELETE'];
    if (methodsWithBody.includes(req.method) && req.body) {
      sanitizeInputs(req.body);
    }
    next();
  });
  app.use(hpp());
}
app.use(rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minuti
  max: 100, // max 100 richieste per 15 minuti per IP
  message: { error: 'Troppe richieste, riprova più tardi.' },
  skip: (req) => process.env.NODE_ENV === 'test'
}));

app.get('/health', (_req, res) => res.json({ status: 'ok' }));
// Endpoint diagnostico per HPP: mostra req.query pulito
app.get('/health/query', (req, res) => {
  // Legge la query string raw e restituisce solo il primo valore per chiave
  const rawQuery = (req.url.split('?')[1] || '').split('#')[0];
  const result = {};
  rawQuery.split('&').forEach(pair => {
    if (!pair) return;
    const [encodedKey, encodedVal] = pair.split('=');
    if (encodedKey && encodedVal !== undefined && !(encodedKey in result)) {
      const key = decodeURIComponent(encodedKey);
      const val = decodeURIComponent(encodedVal);
      result[key] = val;
    }
  });
  res.json(result);
});
app.use('/api-docs', swaggerUi.serve, swaggerUi.setup(swaggerSpec));

// pubbliche
app.use('/auth', require('./routes/auth'));
app.use('/api/vehicle-models', vehicleModelsRouter);

// upload images
app.use('/api/uploads', uploadsRouter);

// file storage endpoints
app.use('/api/files', require('./routes/files'));

// protette
app.use('/users',             authenticate, require('./routes/users'));
app.use('/vehicles',          authenticate, require('./routes/vehicles'));
app.use('/spots',             authenticate, require('./routes/spots'));
app.use('/public-spots',      require('./routes/publicSpots'));
app.use('/recommended-spots', authenticate, require('./routes/recommendedSpots'));
app.use('/favorites',         authenticate, require('./routes/favorites'));
app.use('/maintenance',       authenticate, require('./routes/maintenanceEntries'));
app.use('/camperSpecs',      authenticate, specRouter);
app.use('/camper-specs',     authenticate, specRouter);
app.use('/api/route',         require('./routes/route'));
app.use('/api/recommended-spots', require('./routes/recommendedSpots'));
// app.use('/api', authTestRouter); // COMMENTATO: solo per test

// Route di debug per HPP (solo in sviluppo)
if (process.env.NODE_ENV === 'development') {
  app.get('/debug/query', (req, res) => {
    res.json(req.query);
  });
}

// --- Error handler (must be last) ---
// Ensures 500 errors return a useful JSON body and logs the stack in dev.
app.use((err, req, res, _next) => {
  const status = err.status || err.statusCode || 500;

  // Always log server-side; critical for debugging 500.
  // eslint-disable-next-line no-console
  console.error('Unhandled error:', err);

  const isDev = process.env.NODE_ENV === 'development';
  res.status(status).json({
    error: err.message || 'Internal Server Error',
    status,
    ...(isDev ? { stack: err.stack } : {}),
  });
});

module.exports = app;