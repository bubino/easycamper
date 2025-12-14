'use strict';
const { Model } = require('sequelize');

module.exports = (sequelize, DataTypes) => {
  class CamperSpec extends Model {
    static associate(models) {
      // Solo la relazione CamperSpec → Vehicle
      CamperSpec.belongsTo(models.Vehicle, {
        foreignKey: 'vehicleId',
        as: 'vehicle',
        onDelete: 'CASCADE'
      });
      // rimosso il doppio hasOne per evitare alias duplicati
    }
  }

  CamperSpec.init({
    vehicleId: {
      type: DataTypes.UUID,
      allowNull: false,
      primaryKey: true,
      references: {
        model: 'vehicles',
        key: 'id'
      },
      onUpdate: 'CASCADE',
      onDelete: 'NO ACTION'
    },
    height: { type: DataTypes.FLOAT, allowNull: false },
    width:  { type: DataTypes.FLOAT, allowNull: false },
    length: { type: DataTypes.FLOAT, allowNull: false },
    weight: { type: DataTypes.FLOAT, allowNull: false },
    id: {
      type: DataTypes.VIRTUAL,
      get() { return this.vehicleId; }
    }
  }, {
    sequelize,
    modelName: 'CamperSpec',
    tableName: 'CamperSpecs',
    timestamps: false
  });

  // Hook to support destroy({ where: { id } }) by mapping id to vehicleId
  CamperSpec.addHook('beforeBulkDestroy', options => {
    if (options.where && options.where.id) {
      options.where.vehicleId = options.where.id;
      delete options.where.id;
    }
  });

  return CamperSpec;
};