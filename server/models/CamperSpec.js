'use strict';
const { Model } = require('sequelize');

module.exports = (sequelize, DataTypes) => {
  class CamperSpec extends Model {
    static associate(models) {
      // CamperSpec → Vehicle
      CamperSpec.belongsTo(models.Vehicle, {
        foreignKey: 'vehicleId',
        as: 'vehicle',
      });

      // Vehicle → CamperSpec  (relazione inversa)
      models.Vehicle.hasOne(CamperSpec, {
        foreignKey: 'vehicleId',
        as: 'spec',
      });
    }
  }

  CamperSpec.init(
    {
      vehicleId: {
        type: DataTypes.UUID,
        allowNull: false,
        primaryKey: true,
      },
      height: { type: DataTypes.FLOAT, allowNull: false },
      width:  { type: DataTypes.FLOAT, allowNull: false },
      length: { type: DataTypes.FLOAT, allowNull: false },
      weight: { type: DataTypes.FLOAT, allowNull: false },
    },
    {
      sequelize,
      modelName: 'CamperSpec',
      tableName: 'CamperSpecs',
      timestamps: false,
    },
  );

  return CamperSpec;
};