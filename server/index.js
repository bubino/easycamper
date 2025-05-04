require('dotenv').config();
const express           = require('express');
const helmet            = require('helmet');
const cors              = require('cors');
const cookieParser      = require('cookie-parser');
const swaggerUi         = require('swagger-ui-express');
const swaggerSpec       = require('./swagger');
const { sequelize }     = require('./models');

const app = express();
const PORT = process.env.PORT || 3000;

app.use(helmet());
app.use(cors({ origin: true, credentials: true }));
app.use(express.json());
app.use(cookieParser());

app.get('/health', (req, res) => res.json({ status: 'ok' }));

app.use('/api-docs', swaggerUi.serve, swaggerUi.setup(swaggerSpec));

// qui poi monterai i router:
// app.use('/users',   require('./routes/users'));
// app.use('/vehicles',require('./routes/vehicles'));
// app.use('/spots',   require('./routes/spots'));

async function start() {
  try {
    await sequelize.authenticate();
    console.log('✔️  Database connesso');
    app.listen(PORT, () => {
      console.log(\`🚀  Server in ascolto su http://localhost:\${PORT}\`);
      console.log(\`📚  API docs: http://localhost:\${PORT}/api-docs\`);
    });
  } catch (err) {
    console.error('❌  Impossibile connettersi al DB:', err);
    process.exit(1);
  }
}

start();
