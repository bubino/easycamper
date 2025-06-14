'use strict';

const app = require('./app');
const db  = require('./models');      // importa l’istanza Sequelize

const port = process.env.PORT || 3000;

// Prima apri la connessione al DB
db.sequelize.authenticate()
  .then(() => {
    console.log('🎯 DB connesso');
    // Solo quando il DB è pronto, fai partire Express
    app.listen(port, () => {
      console.log(`🚀 EasyCamper API in ascolto sulla porta ${port}`);
    });
  })
  .catch(err => {
    console.error('❌ Connessione DB fallita:', err);
    process.exit(1);
  });