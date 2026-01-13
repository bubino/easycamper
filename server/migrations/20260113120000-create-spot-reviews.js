'use strict';

module.exports = {
  async up(queryInterface, Sequelize) {
    const dialect = queryInterface.sequelize.getDialect();

    await queryInterface.createTable('spot_reviews', {
      id: {
        type: Sequelize.UUID,
        defaultValue:
          dialect === 'postgres'
            ? Sequelize.literal('uuid_generate_v4()')
            : Sequelize.UUIDV4,
        allowNull: false,
        primaryKey: true,
      },
      spotId: {
        type: Sequelize.UUID,
        allowNull: false,
        field: 'spot_id',
        references: { model: 'spots', key: 'id' },
        onDelete: 'CASCADE',
        onUpdate: 'CASCADE',
      },
      userId: {
        type: Sequelize.UUID,
        allowNull: false,
        field: 'user_id',
        references: { model: 'users', key: 'id' },
        onDelete: 'CASCADE',
        onUpdate: 'CASCADE',
      },
      rating: {
        type: Sequelize.INTEGER,
        allowNull: false,
      },
      comment: {
        type: Sequelize.TEXT,
        allowNull: true,
      },
      createdAt: {
        allowNull: false,
        type: Sequelize.DATE,
        field: 'created_at',
        defaultValue: dialect === 'postgres' ? Sequelize.literal('NOW()') : Sequelize.NOW,
      },
      updatedAt: {
        allowNull: false,
        type: Sequelize.DATE,
        field: 'updated_at',
        defaultValue: dialect === 'postgres' ? Sequelize.literal('NOW()') : Sequelize.NOW,
      },
    });

    await queryInterface.addIndex('spot_reviews', ['spot_id']);
    await queryInterface.addIndex('spot_reviews', ['user_id']);
    await queryInterface.addConstraint('spot_reviews', {
      fields: ['spot_id', 'user_id'],
      type: 'unique',
      name: 'spot_reviews_spot_user_unique',
    });
  },

  async down(queryInterface) {
    await queryInterface.dropTable('spot_reviews');
  },
};
