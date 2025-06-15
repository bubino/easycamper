// cleanup.js
const { Spot, sequelize } = require('./models');

(async () => {
  try {
    await sequelize.authenticate();
    const deleted = await Spot.destroy({
      where: {
        [require('sequelize').Op.or]: [
          { type: null },
          { services: null }
        ]
      }
    });
    console.log(`✅ Spot eliminati: ${deleted}`);
    process.exit(0);
  } catch (err) {
    console.error('❌ Errore nella pulizia:', err);
    process.exit(1);
  }
})();
