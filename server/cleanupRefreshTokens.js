// cleanupRefreshTokens.js
const { RefreshToken, sequelize } = require('./models');

(async () => {
  try {
    await sequelize.authenticate();
    const now = new Date();
    const deleted = await RefreshToken.destroy({
      where: {
        expiresAt: { [require('sequelize').Op.lt]: now }
      }
    });
    console.log(`✅ Refresh token scaduti eliminati: ${deleted}`);
    process.exit(0);
  } catch (err) {
    console.error('❌ Errore nella pulizia refresh token:', err);
    process.exit(1);
  }
})();
