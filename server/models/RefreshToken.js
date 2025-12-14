const { Model } = require('sequelize');

module.exports = (sequelize, DataTypes) => {
  class RefreshToken extends Model {}

  RefreshToken.init({
    id: {
      type: DataTypes.STRING,
      primaryKey: true
    },
    userId: {
      type: DataTypes.STRING,
      allowNull: false,
      field: 'user_id'
    },
    tokenHash: {
      type: DataTypes.STRING(512),
      allowNull: false,
      field: 'token_hash'
    },
    deviceInfo: {
      type: DataTypes.STRING,
      allowNull: true,
      field: 'device_info'
    },
    ip: {
      type: DataTypes.STRING,
      allowNull: true,
      field: 'ip'
    },
    fingerprint: {
      type: DataTypes.STRING,
      allowNull: true,
      field: 'fingerprint'
    },
    expiresAt: {
      type: DataTypes.DATE,
      allowNull: true,
      field: 'expires_at'
    }
  }, {
    sequelize,
    modelName: 'RefreshToken',
    tableName: 'refresh_tokens',
    underscored: true,
    timestamps: true
  });

  return RefreshToken;
};
