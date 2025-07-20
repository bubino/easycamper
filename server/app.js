require('dotenv').config({
  path: process.env.NODE_ENV === 'test' ? '.env.test' : '.env'
});

const express      = require('express');
const helmet       = require('helmet');
const cors         = require('cors');
const cookieParser = require('cookie-parser');
const swaggerUi    = require('swagger-ui-express');
const swaggerSpec  = require('./swagger');
const jwt          = require('jsonwebtoken');

const authenticate = require('./middleware/authenticateToken');
const specRouter   = require('./routes/camperSpecs');
const uploadsRouter= require('./routes/uploads');
const authTestRouter= require('./routes/auth.test');

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

// security middlewares
app.use(helmet());
app.use(cors({ origin: true, credentials: true }));
app.use(express.json());
app.use(cookieParser());

app.get('/health', (_req, res) => res.json({ status: 'ok' }));
app.use('/api-docs', swaggerUi.serve, swaggerUi.setup(swaggerSpec));

// pubbliche
app.use('/auth', require('./routes/auth'));

// upload images
app.use('/api/uploads', uploadsRouter);

// file storage endpoints
app.use('/api/files', require('./routes/files'));

// protette
app.use('/users',             authenticate, require('./routes/users'));
app.use('/vehicles',          authenticate, require('./routes/vehicles'));
app.use('/spots',             authenticate, require('./routes/spots'));
app.use('/public-spots',      authenticate, require('./routes/publicSpots'));
app.use('/recommended-spots', authenticate, require('./routes/recommendedSpots'));
app.use('/favorites',         authenticate, require('./routes/favorites'));
app.use('/maintenance',       authenticate, require('./routes/maintenanceEntries'));
app.use('/camper-specs',      authenticate, specRouter);
app.use('/api/route',         require('./routes/route'));
app.use('/api/recommended-spots', require('./routes/recommendedSpots'));
app.use('/api', authTestRouter);

module.exports = app;