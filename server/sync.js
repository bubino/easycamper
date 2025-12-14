// sync.js
const { sequelize } = require('./models');
const path = require('path');
const fs = require('fs');

async function seedVehicleModels() {
  const db = require('./easycamper/server/models');
  const { VehicleModel } = db;

  const jsonPath = path.join(__dirname, 'easycamper', 'server', 'data', 'vehicle_models.json');
  if (!fs.existsSync(jsonPath)) {
    console.warn('[sync] vehicle_models.json non trovato, salto seed VehicleModels');
    return;
  }

  const raw = fs.readFileSync(jsonPath, 'utf8');
  let models;
  try {
    models = JSON.parse(raw);
  } catch (e) {
    console.error('[sync] Impossibile parsare vehicle_models.json', e);
    return;
  }

  if (!Array.isArray(models) || models.length === 0) {
    console.warn('[sync] vehicle_models.json vuoto, nessun seed VehicleModels eseguito');
    return;
  }

  console.log(`[sync] Seeding VehicleModels con ${models.length} record...`);

  for (const m of models) {
    // Upsert idempotente basato su id
    await VehicleModel.upsert({
      id: m.id,
      brand: m.brand,
      model: m.model,
      year_from: m.year_from,
      length_m: m.length_m,
      height_m: m.height_m,
      weight_kg: m.weight_kg,
      type: m.type,
      brand_slug: m.brand_slug,
    });
  }

  console.log('[sync] Seed VehicleModels completato');
}

async function main() {
  const db = require('./easycamper/server/models');
  await db.sequelize.sync();

  await seedVehicleModels();

  console.log('✅ Sync completata: tutte le tabelle sono aggiornate senza perdita di dati.');
  process.exit(0);
}

main().catch(err => {
  console.error('[sync] Errore durante la sync:', err);
  process.exit(1);
});
