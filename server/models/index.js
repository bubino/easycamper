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
  // SQLite in-memory per test unitari, oppure su file per E2E
  sequelize = new Sequelize({
    dialect: 'sqlite',
    storage: process.env.SQLITE_STORAGE || ':memory:',
    logging: false,
  });
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
//if (env === 'test') {
  // Niente force/drop ⇒ i dati restano tra una request e l’altra
  sequelize.sync();
//}

db.sequelize = sequelize;
db.Sequelize = Sequelize;

module.exports = db;