'use strict';

module.exports = {
  async up(queryInterface, Sequelize) {
    const dialect = queryInterface.sequelize.getDialect();

    // Postgres: JSONB, altri: JSON
    const jsonType = dialect === 'postgres' ? Sequelize.JSONB : Sequelize.JSON;

    await queryInterface.addColumn('spot_reviews', 'photos', {
      type: jsonType,
      allowNull: false,
      defaultValue: [],
    });
  },

  async down(queryInterface) {
    await queryInterface.removeColumn('spot_reviews', 'photos');
  },
};
