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

      Spot.hasMany(models.SpotReview, {
        foreignKey: 'spotId',
        as: 'reviews',
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
      latitude: DataTypes.FLOAT,
      longitude: DataTypes.FLOAT,
      description: DataTypes.TEXT,
      shortDescription: {
        type: DataTypes.STRING,
        allowNull: true,
        field: 'short_description',
      },
      type: {
        type: DataTypes.STRING,
        allowNull: true,
      },
      ratingAverage: {
        type: DataTypes.FLOAT,
        allowNull: true,
        field: 'rating_average',
      },
      ratingCount: {
        type: DataTypes.INTEGER,
        allowNull: true,
        field: 'rating_count',
      },
      services: {
        type: DataTypes.JSONB || DataTypes.JSON,
        allowNull: true,
      },
      tags: {
        type: DataTypes.JSONB || DataTypes.JSON,
        allowNull: true,
      },
      openingHours: {
        type: DataTypes.STRING,
        allowNull: true,
        field: 'opening_hours',
      },
      priceInfo: {
        type: DataTypes.STRING,
        allowNull: true,
        field: 'price_info',
      },
      lastUpdate: {
        type: DataTypes.DATE,
        allowNull: true,
        field: 'last_update',
      },
      photos: {
        type: DataTypes.JSONB || DataTypes.JSON,
        allowNull: false,
        defaultValue: [],
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