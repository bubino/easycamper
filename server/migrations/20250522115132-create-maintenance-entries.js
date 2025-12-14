'use strict';
module.exports = {
  async up(queryInterface, Sequelize) {
    const dialect = queryInterface.sequelize.getDialect();
    await queryInterface.createTable('MaintenanceEntries', {
      id: {
        type: Sequelize.UUID,
        defaultValue: dialect === 'postgres' ? Sequelize.literal('uuid_generate_v4()') : Sequelize.UUIDV4,
        allowNull: false,
        primaryKey: true,
      },
      vehicleId: {
        type: Sequelize.UUID,
        allowNull: false,
        references: { model: 'Vehicles', key: 'id' },
        onDelete: 'CASCADE',
        onUpdate: 'CASCADE',
      },
      description: {
        type: Sequelize.TEXT,
        allowNull: false,
      },
      date: {
        type: Sequelize.DATEONLY,
        allowNull: false,
      },
      cost: {
        type: Sequelize.FLOAT,
        allowNull: true,
      },
      createdAt: {
        allowNull: false,
        type: Sequelize.DATE,
        defaultValue: dialect === 'postgres' ? Sequelize.literal('NOW()') : Sequelize.NOW
      },
      updatedAt: {
        allowNull: false,
        type: Sequelize.DATE,
        defaultValue: dialect === 'postgres' ? Sequelize.literal('NOW()') : Sequelize.NOW
      }
    });
  },
  async down(queryInterface) {
    await queryInterface.dropTable('MaintenanceEntries');
  }
};
