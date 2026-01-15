'use strict';
const fs   = require('fs');
const path = require('path');
const { Sequelize, DataTypes } = require('sequelize');

const env    = process.env.NODE_ENV || 'development';
const config = require(__dirname + '/../config/config.js')[env];

let sequelize;

/*───────────────────────────────────────────────────────────────
  1. Dialetto
───────────────────────────────────────────────────────────────*/
if (env === 'test' || env === 'e2e') {
  // Default: test/e2e su Postgres (docker-compose.test.yml).
  // Eccezione: alcuni test E2E/unit (es. cleanupRefreshTokens) usano volutamente uno SQLite file locale.
  if (process.env.SQLITE_STORAGE && String(process.env.SQLITE_STORAGE).trim().length > 0) {
    sequelize = new Sequelize({
      dialect: 'sqlite',
      storage: process.env.SQLITE_STORAGE,
      logging: false,
    });
  } else {
    const url = process.env.DATABASE_URL;
    if (!url) {
      throw new Error(
        'DATABASE_URL mancante in test/e2e. Avvia Postgres con server/docker-compose.test.yml oppure imposta DATABASE_URL.'
      );
    }
    sequelize = new Sequelize(url, {
      dialect: 'postgres',
      logging: false,
    });
  }
} else if (process.env.DATABASE_URL) {
  // Produzione / staging
  sequelize = new Sequelize(process.env.DATABASE_URL, {
    dialect : 'postgres',
    logging : false,
  });
} else {
  // Ambiente locale (config/*.js)
  sequelize = new Sequelize(
    config.database,
    config.username,
    config.password,
    config,
  );
}

/*───────────────────────────────────────────────────────────────
  2. Caricamento dinamico dei modelli
───────────────────────────────────────────────────────────────*/
const db = {};
const basename = path.basename(__filename);

fs.readdirSync(__dirname)
  .filter(
    file =>
      file.indexOf('.') !== 0 &&
      file !== basename &&
      file.slice(-3) === '.js',
  )
  .forEach(file => {
    console.log(`📄 Caricamento modello: ${file}`);
    const model = require(path.join(__dirname, file))(sequelize, DataTypes);
    db[model.name] = model;
  });

Object.keys(db).forEach(name => {
  if (db[name].associate) db[name].associate(db);
});

/*───────────────────────────────────────────────────────────────
  3. Una sola sync() in ambiente test
───────────────────────────────────────────────────────────────*/
// IMPORTANT: Do NOT call sequelize.sync() at import time.
// Tests and the app bootstrap should decide when to sync/close.
// Automatic sync here caused flaky suites and "Database is closed" errors.

db.sequelize = sequelize;
db.Sequelize = Sequelize;

module.exports = db;