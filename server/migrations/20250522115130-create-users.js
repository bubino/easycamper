'use strict';

module.exports = {
  async up (queryInterface, Sequelize) {
    // Assicurati che l’estensione uuid-ossp sia già abilitata
    await queryInterface.createTable('users', {
      id: {
        type: Sequelize.UUID,
        defaultValue: Sequelize.literal('uuid_generate_v4()'),
        allowNull: false,
        primaryKey: true
      },
      email:        { type: Sequelize.STRING, allowNull: false, unique: true },
      passwordHash: { type: Sequelize.STRING, allowNull: false },
      created_at:   { type: Sequelize.DATE,   allowNull: false, defaultValue: Sequelize.literal('NOW()') },
      updated_at:   { type: Sequelize.DATE,   allowNull: false, defaultValue: Sequelize.literal('NOW()') }
    });
  },

  async down (queryInterface, Sequelize) {
    await queryInterface.dropTable('users');
  }
};