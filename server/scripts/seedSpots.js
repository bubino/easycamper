// scripts/seedSpots.js
'use strict';

require('dotenv').config();
const { Spot, User, sequelize } = require('../models');
const { faker } = require('@faker-js/faker');
const crypto = require('crypto');
const yargs = require('yargs/yargs');
const { hideBin } = require('yargs/helpers');

// ───────────────────────────────────────────────────────────────────────────────
// CLI ARGUMENT PARSING
// -----------------------------------------------------------------------------
const argv = yargs(hideBin(process.argv))
  .option('center-lat', { type: 'number', default: 44.5,        describe: 'Latitudine centro (°)' })
  .option('center-lon', { type: 'number', default: 10.9,        describe: 'Longitudine centro (°)' })
  .option('radius',     { type: 'number', default: 30,          describe: 'Raggio massimo (km)' })
  .option('count',      { type: 'number', default: 50,          describe: 'Numero spot da generare' })
  .option('user-id',    { type: 'string',                       describe: 'UUID utente proprietario spot' })
  .strict()
  .argv;

// ───────────────────────────────────────────────────────────────────────────────
// UTILITIES
// -----------------------------------------------------------------------------
const toRad = deg => deg * (Math.PI / 180);
const toDeg = rad => rad * (180 / Math.PI);
const EARTH_RADIUS_KM = 6371;

// ───────────────────────────────────────────────────────────────────────────────
// MAIN SEED FUNCTION
// -----------------------------------------------------------------------------
async function seed() {
  try {
    await sequelize.authenticate();
    console.log('✔️  Connessione al DB riuscita');

    // ▸ 1. Individua o convalida l'utente proprietario degli spot
    let userId = argv['user-id'];
    if (!userId) {
      const user = await User.findOne({ attributes: ['id'] });
      if (!user) throw new Error('Nessun utente trovato ─ crea un utente o passa --user-id');
      userId = user.id;
    }

    // ▸ 2. Parametri di configurazione
    const centerLat = argv['center-lat'];
    const centerLon = argv['center-lon'];
    const radius    = argv.radius;
    const count     = argv.count;

    // ▸ 3. Genera gli spot fittizi
    const spots = [];
    for (let i = 0; i < count; i++) {
      const theta = Math.random() * 2 * Math.PI;            // angolo
      const dist  = Math.random() * radius;                 // distanza km

      // Approssimazione sferica: calcola delta lat/lon in gradi
      const deltaLat = dist / EARTH_RADIUS_KM;              // rad
      const deltaLon = dist / (EARTH_RADIUS_KM * Math.cos(toRad(centerLat))); // rad

      const lat = centerLat + toDeg(deltaLat * Math.sin(theta));
      const lon = centerLon + toDeg(deltaLon * Math.cos(theta));

      spots.push({
        id:          crypto.randomUUID(),
        userId,                                       // ✅ user associato
        name:        faker.location.streetAddress(),
        description: faker.lorem.sentences(),
        latitude:    parseFloat(lat.toFixed(6)),
        longitude:   parseFloat(lon.toFixed(6)),
        type:        faker.helpers.arrayElement(['gratuito', 'a pagamento']),
        services:    faker.helpers.arrayElements(['wifi', 'elettricita', 'scarico'], { min: 0, max: 3 }),
        features:    faker.helpers.arrayElements(['panoramic', 'ombra', 'tranquillo'], { min: 0, max: 2 }),
        accessible:  faker.datatype.boolean(),
        public:      true,
        maxHeight:   3.5,
        maxWidth:    2.5,
        maxWeight:   5000,
        images:      [],
        createdAt:   new Date(),
        updatedAt:   new Date()
      });
    }

    // ▸ 4. Bulk insert
    await Spot.bulkCreate(spots);
    console.log(`🌱 Inseriti ${count} spot entro ${radius} km dal centro (utente ${userId})`);
    process.exit(0);
  } catch (err) {
    console.error('❌ Errore seedSpots:', err);
    process.exit(1);
  }
}

seed();
