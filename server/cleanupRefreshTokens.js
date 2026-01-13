// cleanupRefreshTokens.js
const { DataTypes, Op } = require('sequelize');

// Use the same sequelize instance/configuration as the app/tests.
// This ensures TEST_DB=postgres and SQLITE_STORAGE are respected.
const { sequelize } = require('./models');

// Load only the RefreshToken model onto the shared sequelize instance.
const RefreshTokenModel = require('./models/RefreshToken');
const RefreshToken = RefreshTokenModel(sequelize, DataTypes);

(async () => {
  try {
    await sequelize.authenticate();
    await sequelize.sync(); // Assicura che la tabella esista

    const now = new Date();
    const deleted = await RefreshToken.destroy({
      where: {
        expiresAt: { [Op.lte]: now },
      },
    });

    console.log(`✅ Refresh token scaduti eliminati: ${deleted}`);
    process.exit(0);
  } catch (err) {
    console.error('❌ Errore nella pulizia refresh token:', err);
    process.exit(1);
  }
})();
