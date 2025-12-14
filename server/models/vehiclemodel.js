'use strict';
const { Model } = require('sequelize');

module.exports = (sequelize, DataTypes) => {
  class VehicleModel extends Model {
    static associate(models) {
      // nessuna associazione obbligatoria per ora
    }
  }

  VehicleModel.init(
    {
      id: {
        type: DataTypes.UUID,
        defaultValue: DataTypes.UUIDV4,
        primaryKey: true,
      },
      brand: {
        type: DataTypes.STRING,
        allowNull: false,
      },
      model: {
        type: DataTypes.STRING,
        allowNull: false,
      },
      year_from: {
        type: DataTypes.INTEGER,
      },
      length_m: {
        type: DataTypes.FLOAT,
      },
      height_m: {
        type: DataTypes.FLOAT,
      },
      weight_kg: {
        type: DataTypes.FLOAT,
      },
      type: {
        type: DataTypes.STRING,
      },
      brand_slug: {
        type: DataTypes.STRING,
      },
    },
    {
      sequelize,
      modelName: 'VehicleModel',
      tableName: 'VehicleModels',
      underscored: false,
      timestamps: false,
    },
  );

  return VehicleModel;
};
