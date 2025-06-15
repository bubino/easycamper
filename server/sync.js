// sync.js
const { sequelize } = require('./models');

(async () => {
  try {
    console.log('⚠️ ATTENZIONE: sync con { force: true } — tutte le tabelle saranno eliminate e ricreate!');
    await sequelize.sync({ force: true });
    console.log('✅ Tutte le tabelle sono state ricreate correttamente.');
    process.exit(0);
  } catch (err) {
    console.error('❌ Errore nella sync forzata:', err);
    process.exit(1);
  }
})();
