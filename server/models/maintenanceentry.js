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
      type: {
        type: DataTypes.STRING,
        allowNull: false,
      },
      notes: {
        type: DataTypes.TEXT,
        allowNull: true,
      },
      date: DataTypes.DATEONLY,
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