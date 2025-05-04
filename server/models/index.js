'use strict';
const fs      = require('fs');
const path    = require('path');
const Sequelize = require('sequelize');
const basename = path.basename(__filename);
const env      = process.env.NODE_ENV || 'development';
const config   = require(__dirname + '/../config/config.js')[env];
const db       = {};

// crea l’istanza Sequelize usando config/config.js
const sequelize = new Sequelize(
  config.database, config.username, config.password, config
);

// carica tutti i file .js tranne questo index.js
fs
  .readdirSync(__dirname)
  .filter(file =>
    file.indexOf('.') !== 0 &&
    file !== basename &&
    file.slice(-3) === '.js'
  )
  .forEach(file => {
    const model = require(path.join(__dirname, file))(sequelize, Sequelize.DataTypes);
    db[model.name] = model;
  });

// esegue eventuali associate()
Object.keys(db).forEach(modelName => {
  if (db[modelName].associate) {
    db[modelName].associate(db);
  }
});

db.sequelize = sequelize;
db.Sequelize = Sequelize;
module.exports = db;
