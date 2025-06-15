'use strict';
const { Model } = require('sequelize');

module.exports = (sequelize, DataTypes) => {
  class Spot extends Model {
    static associate(models) {
      Spot.belongsTo(models.User, {
        foreignKey: 'userId',
        as: 'user',
        onDelete: 'CASCADE',
      });

      Spot.hasMany(models.FavoriteSpot, {
        foreignKey: 'spotId',
        as: 'favorites',
        onDelete: 'CASCADE',
      });
    }
  }

  Spot.init(
    {
      id: {
        type: DataTypes.STRING,
        defaultValue: DataTypes.UUIDV4,
        primaryKey: true,
      },
      userId: {
        type: DataTypes.STRING,
        allowNull: false,
      },
      name: {
        type: DataTypes.STRING,
        allowNull: false,
      },
      lat: DataTypes.FLOAT,
      lng: DataTypes.FLOAT,
      description: DataTypes.TEXT,
    },
    {
      sequelize,
      modelName: 'Spot',
      tableName: 'spots',
      underscored: true,
      timestamps: true,
    },
  );

  return Spot;
};