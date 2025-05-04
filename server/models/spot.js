'use strict';
const { Model } = require('sequelize');

module.exports = (sequelize, DataTypes) => {
  class Spot extends Model {
    static associate(models) {
      Spot.belongsTo(models.User, { foreignKey: 'userId', as: 'owner' });
    }
  }
  Spot.init({
    id:          { type: DataTypes.STRING, primaryKey: true },
    userId:      { type: DataTypes.STRING, allowNull: false },
    name:        { type: DataTypes.STRING, allowNull: false },
    description: DataTypes.TEXT,
    latitude:    { type: DataTypes.FLOAT, allowNull: false },
    longitude:   { type: DataTypes.FLOAT, allowNull: false }
  }, {
    sequelize,
    modelName: 'Spot',
    timestamps: false
  });
  return Spot;
};
