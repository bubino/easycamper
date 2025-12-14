'use strict';

module.exports = {
  up: async (queryInterface, Sequelize) => {
    const tableInfo = await queryInterface.describeTable('spots');
    if (!tableInfo.photos) {
      await queryInterface.addColumn('spots', 'photos', {
        type: Sequelize.JSONB,
        defaultValue: [],
        allowNull: false,
      });
    }
  },

  down: async (queryInterface, Sequelize) => {
    const tableInfo = await queryInterface.describeTable('spots');
    if (tableInfo.photos) {
      await queryInterface.removeColumn('spots', 'photos');
    }
  }
};
