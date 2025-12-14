'use strict';

module.exports = {
  async up(queryInterface, Sequelize) {
    if (queryInterface.sequelize.getDialect() === 'postgres') {
      await queryInterface.sequelize.query(
        'CREATE EXTENSION IF NOT EXISTS "uuid-ossp";'
      );
    }
    // In SQLite (test), non fare nulla
  },
  async down(queryInterface, Sequelize) {
    if (queryInterface.sequelize.getDialect() === 'postgres') {
      await queryInterface.sequelize.query(
        'DROP EXTENSION IF EXISTS "uuid-ossp";'
      );
    }
    // In SQLite (test), non fare nulla
  }
};