'use strict';

const { sequelize, Spot } = require('../models');

async function seedDemoSpots() {
  try {
    await sequelize.authenticate();

    const count = await Spot.count();
    if (count > 0) {
      console.log(`[seed_spots_demo] Spots già presenti (${count}), non inserisco demo.`);
      return;
    }

    await Spot.bulkCreate([
      {
        id: 'spot1',
        // NOTA: userId è richiesto dalla migrazione originale; usiamo un UUID fittizio
        userId: '00000000-0000-0000-0000-000000000001',
        name: 'Area Sosta Milano Nord',
        description:
          'Area sosta attrezzata con elettricità, acqua, scarico e videosorveglianza. Ottima base per visitare Milano.',
        latitude: 45.47,
        longitude: 9.18,
        type: 'area_sosta',
      },
      {
        id: 'spot2',
        userId: '00000000-0000-0000-0000-000000000001',
        name: 'Campeggio Navigli',
        description:
          'Campeggio immerso nel verde, piazzole grandi, ristorante interno, market e area giochi per bambini.',
        latitude: 45.4642,
        longitude: 9.19,
        type: 'campeggio',
      },
      {
        id: 'spot3',
        userId: '00000000-0000-0000-0000-000000000001',
        name: 'Area Sosta Centro Storico',
        description:
          'Area sosta vicina al centro, accesso 24h, bagni puliti, ottima per visitare la città a piedi.',
        latitude: 45.465,
        longitude: 9.192,
        type: 'area_sosta',
      },
    ]);

    console.log('[seed_spots_demo] Inseriti 3 spot demo (schema legacy).');
  } catch (err) {
    console.error('[seed_spots_demo] Errore durante il seeding:', err);
    process.exitCode = 1;
  } finally {
    await sequelize.close();
  }
}

seedDemoSpots();
