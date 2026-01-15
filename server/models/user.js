'use strict';
const { Model } = require('sequelize');
const bcrypt = require('bcrypt');

module.exports = (sequelize, DataTypes) => {
  class User extends Model {
    async validatePassword(password) {
      return bcrypt.compare(password, this.password);
    }

    static associate(models) {
      User.hasMany(models.SpotReview, {
        foreignKey: 'userId',
        as: 'spotReviews',
        onDelete: 'CASCADE',
      });
    }
  }

  User.init({
    id: {
      type: DataTypes.UUID,
      defaultValue: DataTypes.UUIDV4,
      primaryKey: true
    },
    username: {
      type: DataTypes.STRING,
      allowNull: true,
      unique: true
    },
    email:        { type: DataTypes.STRING, allowNull: false, unique: true },
    password: {
      type: DataTypes.STRING,
      allowNull: false
    },
    refreshToken: {
      type: DataTypes.STRING,
      allowNull: true
    },
    emailVerified: {
      type: DataTypes.BOOLEAN,
      defaultValue: false,
      allowNull: false
    },
    emailChangeToken: {
      type: DataTypes.STRING,
      allowNull: true
    },
    emailChangeNew: {
      type: DataTypes.STRING,
      allowNull: true
    },
    emailChangeRequestedAt: {
      type: DataTypes.DATE,
      allowNull: true
    },
    avatarKey: {
      type: DataTypes.STRING,
      allowNull: true,
      field: 'avatar_key',
    },
  }, {
    sequelize,
    modelName: 'User',
    tableName: 'users',
    underscored: true,
    timestamps: true,
    hooks: {
      beforeCreate: async (user) => {
        if (user.password) {
          const salt = await bcrypt.genSalt(10);
          user.password = await bcrypt.hash(user.password, salt);
        }
      },
      beforeUpdate: async (user) => {
        if (user.changed('password')) {
          const salt = await bcrypt.genSalt(10);
          user.password = await bcrypt.hash(user.password, salt);
        }
      }
    }
  });

  return User;
};