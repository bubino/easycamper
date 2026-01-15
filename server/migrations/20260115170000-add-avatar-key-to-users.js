'use strict';

module.exports = {
  async up(queryInterface, Sequelize) {
    await queryInterface.addColumn('users', 'avatar_key', {
      type: Sequelize.STRING,
      allowNull: true,
    });

    // indice semplice per lookup/debug (non unique)
    await queryInterface.addIndex('users', ['avatar_key']);
  },

  async down(queryInterface, _Sequelize) {
    await queryInterface.removeIndex('users', ['avatar_key']);
    await queryInterface.removeColumn('users', 'avatar_key');
  },
};
