// cleanupRefreshTokens.js
const { Sequelize, DataTypes, Op } = require('sequelize');
// Choose DB: SQLite file if provided, otherwise Postgres via DATABASE_URL
let sequelize;
if (process.env.DATABASE_URL) {
  sequelize = new Sequelize(process.env.DATABASE_URL, { dialect: 'postgres', logging: false });
} else {
  const storage = process.env.SQLITE_STORAGE || ':memory:';
  sequelize = new Sequelize({ dialect: 'sqlite', storage, logging: false });
}
// Load only the RefreshToken model
const RefreshTokenModel = require('./models/RefreshToken');
const RefreshToken = RefreshTokenModel(sequelize, DataTypes);

(async () => {
  try {
    await sequelize.authenticate();
    await sequelize.sync(); // Assicura che la tabella esista
    // Usa now - 1 secondo per evitare problemi di precisione
    const now = new Date(Date.now() - 1000);
    const deleted = await RefreshToken.destroy({
      where: {
        expiresAt: { [Op.lt]: now }
      }
    });
    console.log(`✅ Refresh token scaduti eliminati: ${deleted}`);
    process.exit(0);
  } catch (err) {
    console.error('❌ Errore nella pulizia refresh token:', err);
    process.exit(1);
  }
})();
