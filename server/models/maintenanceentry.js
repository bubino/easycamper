'use strict';
const { Model } = require('sequelize');

module.exports = (sequelize, DataTypes) => {
  class MaintenanceEntry extends Model {
    static associate(models) {
      MaintenanceEntry.belongsTo(models.User, {
        foreignKey: 'userId',
        as: 'user',
        onDelete: 'CASCADE',
      });
      MaintenanceEntry.belongsTo(models.Vehicle, {
        foreignKey: 'vehicleId',
        as: 'vehicle',
        onDelete: 'CASCADE',
      });
    }
  }

  MaintenanceEntry.init(
    {
      id: {
        type: DataTypes.STRING,
        defaultValue: DataTypes.UUIDV4,
        primaryKey: true,
      },
      userId: {
        type: DataTypes.UUID,
        allowNull: false,
      },
      vehicleId: {
        type: DataTypes.UUID,
        allowNull: true,
      },
      description: {
        type: DataTypes.TEXT,
        allowNull: true,
      },
      date: DataTypes.DATEONLY,
      cost: DataTypes.FLOAT,
    },
    {
      sequelize,
      modelName: 'MaintenanceEntry',
      tableName: 'maintenance_entries',
      underscored: true,
      timestamps: true,
    },
  );

  return MaintenanceEntry;
};