'use strict';
const { Model } = require('sequelize');

module.exports = (sequelize, DataTypes) => {
  class Vehicle extends Model {
    static associate(models) {
      Vehicle.belongsTo(models.User, {
        foreignKey: 'userId',
        as: 'user',
        onDelete: 'CASCADE',
      });
      Vehicle.hasMany(models.MaintenanceEntry, {
        foreignKey: 'vehicleId',
        as: 'maintenanceEntries',
        onDelete: 'CASCADE',
      });
    }
  }

  Vehicle.init(
    {
      id: {
        type: DataTypes.STRING,           // UUID serializzato
        defaultValue: DataTypes.UUIDV4,
        primaryKey: true,
      },
      userId: {
        type: DataTypes.STRING,
        allowNull: false,
      },
      make:  DataTypes.STRING,
      model: DataTypes.STRING,
      year:  DataTypes.INTEGER,
      length: DataTypes.FLOAT,
      height: DataTypes.FLOAT,
      weight: DataTypes.FLOAT,
    },
    {
      sequelize,
      modelName: 'Vehicle',
      tableName: 'vehicles',
      underscored: true,
      timestamps: true,
    },
  );

  return Vehicle;
};