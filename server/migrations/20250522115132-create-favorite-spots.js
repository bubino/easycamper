'use strict';

module.exports = {
  async up(queryInterface, Sequelize) {
    const dialect = queryInterface.sequelize.getDialect();
    await queryInterface.createTable('FavoriteSpots', {
      id: {
        allowNull: false,
        primaryKey: true,
        type: Sequelize.UUID,
        defaultValue: dialect === 'postgres' ? Sequelize.literal('uuid_generate_v4()') : Sequelize.UUIDV4
      },
      userId: {
        type: Sequelize.UUID,
        allowNull: false,
        references: { model: 'Users', key: 'id' },
        onDelete: 'CASCADE'
      },
      spotId: {
        type: Sequelize.UUID,
        allowNull: false,
        references: { model: 'Spots', key: 'id' },
        onDelete: 'CASCADE'
      },
      createdAt: { allowNull: false, type: Sequelize.DATE, defaultValue: dialect === 'postgres' ? Sequelize.fn('now') : Sequelize.NOW },
      updatedAt: { allowNull: false, type: Sequelize.DATE, defaultValue: dialect === 'postgres' ? Sequelize.fn('now') : Sequelize.NOW }
    });
    await queryInterface.addIndex('FavoriteSpots', ['userId']);
    await queryInterface.addIndex('FavoriteSpots', ['spotId']);
  },

  async down(queryInterface) {
    await queryInterface.dropTable('FavoriteSpots');
  }
};
