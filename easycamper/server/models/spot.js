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

      Spot.hasMany(models.SpotImage, {
        foreignKey: 'spotId',
        as: 'images',
        onDelete: 'CASCADE',
      });
    }
  }

  Spot.init(
    {
      id: {
        type: DataTypes.UUID,
        defaultValue: DataTypes.UUIDV4,
        primaryKey: true,
      },
      userId: {
        type: DataTypes.UUID,
        allowNull: false,
      },
      name: {
        type: DataTypes.STRING,
        allowNull: false,
      },
      lat: DataTypes.FLOAT,
      lng: DataTypes.FLOAT,
      description: DataTypes.TEXT,
      // Nuovi campi
      type: DataTypes.STRING, // es. 'area_sosta'
      services: {
        type: DataTypes.JSON, // Array di stringhe o oggetto bool
        defaultValue: [],
      },
      rating: {
        type: DataTypes.FLOAT,
        defaultValue: 0,
      },
      public: {
        type: DataTypes.BOOLEAN,
        defaultValue: true,
      },
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