'use strict';

const app = require('./app');
const db  = require('./models');      // importa l’istanza Sequelize

const port = process.env.PORT || 3000;

// Prima apri la connessione al DB
db.sequelize.authenticate()
  .then(async () => {
    console.log('🎯 DB connesso');
    if (process.env.NODE_ENV === 'development') {
      await db.sequelize.sync({ alter: true });
      console.log('🔄 Database schema aggiornato (alter)');
    }
    // --- SYNC DISABILITATA PER DEBUG POSTGRES ---
    // return db.User.sync({ force: true })
    //   .then(() => db.Vehicle.sync({ force: true }))
    //   .then(() => db.CamperSpec.sync({ force: true }))
    //   .then(() => db.Spot.sync({ force: true }))
    //   .then(() => db.MaintenanceEntry.sync({ force: true }))
    //   .then(() => db.FavoriteSpot.sync({ force: true }))
    //   .then(() => db.RefreshToken.sync({ force: true }));
    // Avvio server senza sync
    app.listen(port, () => {
      console.log(`🚀 EasyCamper API in ascolto sulla porta ${port}`);
    });
  })
  .catch(err => {
    console.error('❌ Connessione DB fallita:', err);
    process.exit(1);
  });