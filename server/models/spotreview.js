'use strict';
const { Model } = require('sequelize');

module.exports = (sequelize, DataTypes) => {
  class SpotReview extends Model {
    static associate(models) {
      SpotReview.belongsTo(models.Spot, {
        foreignKey: 'spotId',
        as: 'spot',
        onDelete: 'CASCADE',
      });
      SpotReview.belongsTo(models.User, {
        foreignKey: 'userId',
        as: 'user',
        onDelete: 'CASCADE',
      });
    }
  }

  SpotReview.init(
    {
      id: {
        type: DataTypes.UUID,
        defaultValue: DataTypes.UUIDV4,
        primaryKey: true,
      },
      spotId: {
        type: DataTypes.UUID,
        allowNull: false,
        field: 'spot_id',
      },
      userId: {
        type: DataTypes.UUID,
        allowNull: false,
        field: 'user_id',
      },
      rating: {
        type: DataTypes.INTEGER,
        allowNull: false,
        validate: {
          min: 1,
          max: 5,
        },
      },
      comment: {
        type: DataTypes.TEXT,
        allowNull: true,
      },
      photos: {
        type: DataTypes.JSONB || DataTypes.JSON,
        allowNull: false,
        defaultValue: [],
      },
    },
    {
      sequelize,
      modelName: 'SpotReview',
      tableName: 'spot_reviews',
      underscored: true,
      timestamps: true,
    },
  );

  return SpotReview;
};