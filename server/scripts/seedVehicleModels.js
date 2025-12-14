#!/usr/bin/env node

// Script di seed per la tabella VehicleModels

const path = require('path');
const fs = require('fs');

const db = require('../easycamper/server/models');

async function main() {
  try {
    const filePath = path.join(__dirname, '../easycamper/server/data/vehicle_models.json');
    const raw = fs.readFileSync(filePath, 'utf8');
    const items = JSON.parse(raw);

    if (!Array.isArray(items)) {
      throw new Error('vehicle_models.json deve contenere un array');
    }

    console.log(`Seed VehicleModels: trovati ${items.length} elementi`);

    await db.sequelize.authenticate();

    const { VehicleModel } = db;

    await VehicleModel.bulkCreate(items, {
      ignoreDuplicates: true,
    });

    console.log('Seed VehicleModels completato');
  } catch (err) {
    console.error('Errore nel seed VehicleModels', err);
    process.exit(1);
  } finally {
    await db.sequelize.close();
  }
}

main();
