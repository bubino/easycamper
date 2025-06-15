'use strict';
const { Model } = require('sequelize');

module.exports = (sequelize, DataTypes) => {
  class User extends Model {
    static associate(models) {
      User.hasMany(models.Vehicle, {
        foreignKey: 'userId',
        as: 'vehicles',
        onDelete: 'CASCADE',
      });
      User.hasMany(models.FavoriteSpot, {
        foreignKey: 'userId',
        as: 'favoriteSpots',
        onDelete: 'CASCADE',
      });
      User.hasMany(models.MaintenanceEntry, {
        foreignKey: 'userId',
        as: 'maintenanceEntries',
        onDelete: 'CASCADE',
      });
      User.hasMany(models.Spot, {
        foreignKey: 'userId',
        as: 'spots',
        onDelete: 'CASCADE',
      });
    }
  }

  User.init(
    {
      id: {
        type: DataTypes.STRING,          // UUID serializzato
        defaultValue: DataTypes.UUIDV4,
        primaryKey: true,
      },
      username: {
        type: DataTypes.STRING,
        allowNull: false,
        unique: true,
      },
      passwordHash: {
        type: DataTypes.STRING,
        allowNull: true,                 // opzionale nei test
      },
      role: {
        type: DataTypes.ENUM('user', 'admin'),
        defaultValue: 'user',
      },
    },
    {
      sequelize,
      modelName: 'User',
      tableName: 'users',
      underscored: true,
      timestamps: true,
    },
  );

  return User;
};