'use strict';

module.exports = {
  async up (queryInterface, Sequelize) {
    const dialect = queryInterface.sequelize.getDialect();
    await queryInterface.createTable('vehicles', {
      id: {
        type: Sequelize.UUID,
        defaultValue: dialect === 'postgres' ? Sequelize.literal('uuid_generate_v4()') : Sequelize.UUIDV4,
        allowNull: false,
        primaryKey: true
      },
      user_id: {
        type: Sequelize.UUID,
        allowNull: false,
        references: {
          model: 'users',
          key: 'id'
        },
        onUpdate: 'CASCADE',
        onDelete: 'CASCADE'
      },
      make:      { type: Sequelize.STRING },
      model:     { type: Sequelize.STRING },
      year:      { type: Sequelize.INTEGER },
      length:    { type: Sequelize.FLOAT },
      height:    { type: Sequelize.FLOAT },
      weight:    { type: Sequelize.FLOAT },
      created_at:{ type: Sequelize.DATE, allowNull: false, defaultValue: dialect === 'postgres' ? Sequelize.literal('NOW()') : Sequelize.NOW },
      updated_at:{ type: Sequelize.DATE, allowNull: false, defaultValue: dialect === 'postgres' ? Sequelize.literal('NOW()') : Sequelize.NOW }
    });
  },

  async down (queryInterface, Sequelize) {
    await queryInterface.dropTable('vehicles');
  }
};