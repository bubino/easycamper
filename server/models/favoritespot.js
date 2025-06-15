// models/favoritespot.js
'use strict';

const { Model } = require('sequelize');

module.exports = (sequelize, DataTypes) => {
  class FavoriteSpot extends Model {
    static associate(models) {
      // qui models.User e models.Spot esistono davvero
      FavoriteSpot.belongsTo(models.User, { foreignKey: 'userId', as: 'user' });
      FavoriteSpot.belongsTo(models.Spot, { foreignKey: 'spotId', as: 'spot' });
    }
  }

  FavoriteSpot.init({
    userId: {
      type: DataTypes.UUID,
      allowNull: false,
    },
    spotId: {
      type: DataTypes.UUID,
      allowNull: false,
    },
  }, {
    sequelize,
    modelName: 'FavoriteSpot',
    tableName: 'FavoriteSpots',
    timestamps: false,     // o true se vuoi createdAt/updatedAt
  });

  return FavoriteSpot;
};
