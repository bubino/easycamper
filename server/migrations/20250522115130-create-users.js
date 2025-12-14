'use strict';

module.exports = {
  async up (queryInterface, Sequelize) {
    const dialect = queryInterface.sequelize.getDialect();
    await queryInterface.createTable('Users', {
      id: {
        type: Sequelize.UUID,
        defaultValue: dialect === 'postgres' ? Sequelize.literal('uuid_generate_v4()') : Sequelize.UUIDV4,
        allowNull: false,
        primaryKey: true
      },
      email:        { type: Sequelize.STRING, allowNull: false, unique: true },
      passwordHash: { type: Sequelize.STRING, allowNull: false },
      created_at:   { type: Sequelize.DATE, allowNull: false, defaultValue: dialect === 'postgres' ? Sequelize.literal('NOW()') : Sequelize.NOW },
      updated_at:   { type: Sequelize.DATE, allowNull: false, defaultValue: dialect === 'postgres' ? Sequelize.literal('NOW()') : Sequelize.NOW }
    });
  },

  async down (queryInterface, Sequelize) {
    await queryInterface.dropTable('Users');
  }
};