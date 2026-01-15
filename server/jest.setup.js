process.env.JWT_SECRET = 'testsecret';

// Mock globali per servizi esterni
jest.mock('services/ghAxios');
jest.mock('utils/polylineUtils');
jest.mock('utils/shardUtils');
jest.mock('nodemailer'); // Riattivato mock nodemailer per ambiente di test

// --- Fetch mock ---
// Nota: alcuni test usano global.fetch.mockResolvedValue / mockImplementationOnce.
// Quindi serve un jest.fn() (non una spy su una implementazione reale).
if (!global.fetch || typeof global.fetch !== 'function' || !('mock' in global.fetch)) {
  global.fetch = jest.fn();
}

// Default: risposta OK vuota (personalizzabile nei singoli test con mockImplementationOnce ecc.)
global.fetch.mockImplementation(async () => ({
  ok: true,
  status: 200,
  json: async () => ({}),
  text: async () => '',
}));

// --- DB bootstrap per test ---
// Decisione progetto: per coerenza con produzione usiamo Postgres anche nei test.
if (process.env.NODE_ENV === 'test' || process.env.NODE_ENV === 'e2e') {
  // Default per docker-compose.test.yml
  if (!process.env.DATABASE_URL) {
    process.env.DATABASE_URL =
      process.env.TEST_DATABASE_URL ||
      'postgres://easycamper:secret123@127.0.0.1:5433/easycamper_test';
  }
}

const db = require('./models');

async function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

async function waitForDbReady({ retries = 25, delayMs = 250 } = {}) {
  let lastErr;
  for (let i = 0; i < retries; i++) {
    try {
      await db.sequelize.authenticate();
      return;
    } catch (e) {
      lastErr = e;
      await sleep(delayMs);
    }
  }
  // eslint-disable-next-line no-console
  console.error('Sequelize authenticate failed after retries in jest.setup:', lastErr);
  throw lastErr;
}

beforeAll(async () => {
  await waitForDbReady();
  await db.sequelize.sync({ force: true });
});

// Nota: NON chiudiamo qui la connessione.
// Molti file di test chiamano già db.sequelize.close()/sequelize.close() in afterAll.
// Chiudere globalmente qui causa SQLITE_MISUSE/"Database is closed" quando avviene un double-close.