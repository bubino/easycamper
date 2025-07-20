const { RefreshToken, sequelize } = require('../models');
const { execSync } = require('child_process');

describe('Cleanup refresh tokens', () => {
  beforeAll(async () => {
    await sequelize.sync({ force: true });
  });

  it('should remove only expired refresh tokens', async () => {
    // Token scaduto
    await RefreshToken.create({
      userId: '11111111-1111-1111-1111-111111111111',
      tokenHash: 'expiredtoken',
      deviceInfo: 'DeviceA',
      createdAt: new Date(Date.now() - 8 * 24 * 60 * 60 * 1000),
      expiresAt: new Date(Date.now() - 1 * 24 * 60 * 60 * 1000)
    });
    // Token valido
    await RefreshToken.create({
      userId: '22222222-2222-2222-2222-222222222222',
      tokenHash: 'validtoken',
      deviceInfo: 'DeviceB',
      createdAt: new Date(),
      expiresAt: new Date(Date.now() + 6 * 24 * 60 * 60 * 1000)
    });

    // Esegui lo script di cleanup
    execSync('node server/cleanupRefreshTokens.js');

    // Verifica che il token scaduto sia stato eliminato
    const expired = await RefreshToken.findOne({ where: { tokenHash: 'expiredtoken' } });
    expect(expired).toBeNull();
    // Verifica che il token valido sia ancora presente
    const valid = await RefreshToken.findOne({ where: { tokenHash: 'validtoken' } });
    expect(valid).not.toBeNull();
  });
});