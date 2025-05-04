'use strict';
const { Model } = require('sequelize');

module.exports = (sequelize, DataTypes) => {
  class MaintenanceEntry extends Model {
    static associate(models) {
      MaintenanceEntry.belongsTo(models.Vehicle, { foreignKey: 'vehicleId', as: 'vehicle' });
    }
  }
  MaintenanceEntry.init({
    id:        { type: DataTypes.STRING, primaryKey: true },
    vehicleId: { type: DataTypes.STRING, allowNull: false },
    date:      { type: DataTypes.DATEONLY, allowNull: false },
    type:      { type: DataTypes.ENUM('tagliando','riparazione','controllo'), allowNull: false },
    notes:     DataTypes.TEXT
  }, {
    sequelize,
    modelName: 'MaintenanceEntry',
    timestamps: true
  });
  return MaintenanceEntry;
};
