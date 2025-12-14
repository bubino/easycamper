'use strict';

const app = require('./app');
const db  = require('./models');      // importa l’istanza Sequelize

const port = process.env.PORT || 3000;

// Prima apri la connessione al DB
db.sequelize.authenticate()
  .then(async () => {
    console.log('🎯 DB connesso');
    
    // Sincronizza i modelli con il DB (crea tabelle/colonne mancanti)
    // In produzione si userebbero le migrazioni, ma per sviluppo questo è comodo.
    if (process.env.NODE_ENV !== 'production') {
      try {
        await db.sequelize.sync({ alter: true });
        console.log('✅ DB sincronizzato (alter: true)');
      } catch (syncErr) {
        console.error('⚠️ Errore durante sync DB:', syncErr);
      }
    }

    // Solo quando il DB è pronto, fai partire Express
    app.listen(port, () => {
      console.log(`🚀 EasyCamper API in ascolto sulla porta ${port}`);
    });
  })
  .catch(err => {
    console.error('❌ Connessione DB fallita:', err);
    process.exit(1);
  });