const path = require('path');
const fs = require('fs');
const { spawn } = require('child_process');
const { Sequelize, DataTypes } = require('sequelize');
const dbPath = path.join(__dirname, '../tmp-refresh-token-test.sqlite');

// Rimuovi il db temporaneo se esiste
afterAll(() => {
  if (fs.existsSync(dbPath)) fs.unlinkSync(dbPath);
});

describe('E2E cleanupRefreshTokens.js', () => {
  let sequelize, RefreshToken;

  beforeAll(async () => {
    sequelize = new Sequelize({
      dialect: 'sqlite',
      storage: dbPath,
      logging: false,
    });
    RefreshToken = require('../models/RefreshToken')(sequelize, DataTypes);
    await sequelize.sync({ force: true });
  });

  it('should remove only expired refresh tokens (E2E)', async () => {
    jest.setTimeout(20000); // Aumenta timeout a 20 secondi
    // Inserisci due token: uno scaduto, uno valido
    await RefreshToken.create({
      id: '1',
      userId: 'u1',
      tokenHash: 'expiredtoken',
      deviceInfo: 'DeviceA',
      expiresAt: new Date(Date.now() - 1000 * 60 * 60), // scaduto
    });
    await RefreshToken.create({
      id: '2',
      userId: 'u2',
      tokenHash: 'validtoken',
      deviceInfo: 'DeviceB',
      expiresAt: new Date(Date.now() + 1000 * 60 * 60), // valido
    });
    await sequelize.close(); // Chiudi la connessione per evitare lock

    // Lancia lo script cleanupRefreshTokens.js con NODE_ENV=test e storage custom
    await new Promise((resolve, reject) => {
      const child = spawn(
        process.execPath,
        [path.join(__dirname, '../cleanupRefreshTokens.js')],
        {
          env: {
            ...process.env,
            NODE_ENV: 'test',
            // This E2E test is intentionally SQLite-file based.
            // Force the cleanup script to use the same SQLite DB even when the overall suite is running with TEST_DB=postgres.
            TEST_DB: '',
            DATABASE_URL: '',
            SQLITE_STORAGE: dbPath,
          },
          stdio: 'inherit',
        }
      );
      child.on('exit', code => {
        if (code === 0) resolve();
        else reject(new Error('cleanupRefreshTokens.js failed'));
      });
    });

    // Riapri la connessione e verifica
    sequelize = new Sequelize({
      dialect: 'sqlite',
      storage: dbPath,
      logging: false,
    });
    RefreshToken = require('../models/RefreshToken')(sequelize, DataTypes);
    const expired = await RefreshToken.findOne({ where: { tokenHash: 'expiredtoken' } });
    const valid = await RefreshToken.findOne({ where: { tokenHash: 'validtoken' } });
    expect(expired).toBeNull();
    expect(valid).not.toBeNull();
    await sequelize.close(); // Chiudi solo alla fine
  });
});
