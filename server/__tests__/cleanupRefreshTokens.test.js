const path = require('path');
const fs = require('fs');
const { execSync } = require('child_process');
const { Sequelize, DataTypes } = require('sequelize');
const dbPath = path.join(__dirname, '../tmp-refresh-token-unitest.sqlite');

// Cleanup file dopo i test
afterAll(() => {
  if (fs.existsSync(dbPath)) fs.unlinkSync(dbPath);
});

describe('Cleanup refresh tokens', () => {
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

  afterAll(async () => {
    await sequelize.close();
  });

  it('should remove only expired refresh tokens', async () => {
    // Token scaduto
    await RefreshToken.create({
      id: require('uuid').v4(),
      userId: '11111111-1111-1111-1111-111111111111',
      tokenHash: 'expiredtoken',
      deviceInfo: 'DeviceA',
      createdAt: new Date('2024-07-14T18:11:05.419Z'),
      updatedAt: new Date('2024-07-14T18:11:05.419Z'),
      expiresAt: new Date('2024-07-21T18:11:05.419Z')
    });
    // Token valido
    await RefreshToken.create({
      id: require('uuid').v4(),
      userId: '22222222-2222-2222-2222-222222222222',
      tokenHash: 'validtoken',
      deviceInfo: 'DeviceB',
      createdAt: new Date(),
      updatedAt: new Date(),
      expiresAt: new Date(Date.now() + 6 * 24 * 60 * 60 * 1000)
    });
    await sequelize.close(); // Chiudi la connessione per evitare lock

    // Esegui lo script di cleanup con la stessa variabile d'ambiente
    execSync('node cleanupRefreshTokens.js', {
      cwd: path.join(__dirname, '..'),
      env: { ...process.env, NODE_ENV: 'test', SQLITE_STORAGE: dbPath },
      stdio: 'inherit',
    });

    // Riapri la connessione e verifica
    sequelize = new Sequelize({
      dialect: 'sqlite',
      storage: dbPath,
      logging: false,
    });
    RefreshToken = require('../models/RefreshToken')(sequelize, DataTypes);
    const expired = await RefreshToken.findOne({ where: { tokenHash: 'expiredtoken' } });
    expect(expired).toBeNull();
    const valid = await RefreshToken.findOne({ where: { tokenHash: 'validtoken' } });
    expect(valid).not.toBeNull();
  });
});