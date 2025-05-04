'use strict';
const { Model } = require('sequelize');

module.exports = (sequelize, DataTypes) => {
  class User extends Model {
    static associate(models) {
      User.hasMany(models.Vehicle, { foreignKey: 'userId', as: 'vehicles' });
      User.hasMany(models.Spot,    { foreignKey: 'userId', as: 'spots'   });
    }
  }
  User.init({
    id:           { type: DataTypes.STRING, primaryKey: true },
    username:     { type: DataTypes.STRING, allowNull: false, unique: true },
    passwordHash: { type: DataTypes.STRING, allowNull: false }
  }, {
    sequelize,
    modelName: 'User',
    timestamps: false
  });
  return User;
};
