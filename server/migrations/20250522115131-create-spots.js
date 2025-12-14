'use strict';
module.exports = {
  async up(queryInterface, Sequelize) {
    const dialect = queryInterface.sequelize.getDialect();
    await queryInterface.createTable('Spots', {
      id: {
        type: Sequelize.UUID,
        defaultValue: dialect === 'postgres' ? Sequelize.literal('uuid_generate_v4()') : Sequelize.UUIDV4,
        allowNull: false,
        primaryKey: true,
      },
      userId: {
        type: Sequelize.UUID,
        allowNull: false,
        references: { model: 'Users', key: 'id' },
        onDelete: 'CASCADE',
        onUpdate: 'CASCADE',
      },
      name: {
        type: Sequelize.STRING,
        allowNull: false,
      },
      description: {
        type: Sequelize.TEXT,
        allowNull: true,
      },
      latitude: {
        type: Sequelize.FLOAT,
        allowNull: false,
      },
      longitude: {
        type: Sequelize.FLOAT,
        allowNull: false,
      },
      type: {
        type: Sequelize.STRING,
        allowNull: true,
      },
      services: {
        type: dialect === 'postgres' ? Sequelize.ARRAY(Sequelize.STRING) : Sequelize.TEXT,
        allowNull: true,
      },
      features: {
        type: dialect === 'postgres' ? Sequelize.ARRAY(Sequelize.STRING) : Sequelize.TEXT,
        allowNull: true,
      },
      images: {
        type: dialect === 'postgres' ? Sequelize.ARRAY(Sequelize.STRING) : Sequelize.TEXT,
        allowNull: true,
      },
      accessible: {
        type: Sequelize.BOOLEAN,
        allowNull: true,
      },
      public: {
        type: Sequelize.BOOLEAN,
        allowNull: false,
        defaultValue: false,
      },
      maxHeight: {
        type: Sequelize.FLOAT,
        allowNull: true,
      },
      maxWidth: {
        type: Sequelize.FLOAT,
        allowNull: true,
      },
      maxWeight: {
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
    await queryInterface.dropTable('Spots');
  }
};
