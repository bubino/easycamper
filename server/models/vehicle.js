'use strict';
const { Model } = require('sequelize');

module.exports = (sequelize, DataTypes) => {
  class Vehicle extends Model {
    static associate(models) {
      Vehicle.belongsTo(models.User,            { foreignKey: 'userId',    as: 'owner'      });
      Vehicle.hasMany(models.MaintenanceEntry,  { foreignKey: 'vehicleId', as: 'maintenance' });
    }
  }
  Vehicle.init({
    id:       { type: DataTypes.STRING, primaryKey: true },
    userId:   { type: DataTypes.STRING, allowNull: false },
    type:     { type: DataTypes.ENUM('camper','van','motorhome'), allowNull: false },
    make:     { type: DataTypes.STRING, allowNull: false },
    model:    { type: DataTypes.STRING, allowNull: false },
    // campi extra (altezza, lunghezza, peso, imageUrl) se li vorrai aggiungere:
    height:   DataTypes.FLOAT,
    length:   DataTypes.FLOAT,
    weight:   DataTypes.FLOAT,
    imageUrl: DataTypes.STRING
  }, {
    sequelize,
    modelName: 'Vehicle',
    timestamps: true
  });
  return Vehicle;
};
