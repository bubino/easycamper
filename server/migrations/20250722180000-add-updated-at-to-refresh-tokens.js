'use strict';

module.exports = {
  up: async (queryInterface, Sequelize) => {
    // 1. Aggiungi la colonna come nullable
    await queryInterface.addColumn('refresh_tokens', 'updated_at', {
      type: Sequelize.DATE,
      allowNull: true,
      defaultValue: Sequelize.literal('CURRENT_TIMESTAMP')
    });
    // 2. Aggiorna tutte le righe esistenti
    await queryInterface.sequelize.query(
      "UPDATE refresh_tokens SET updated_at = CURRENT_TIMESTAMP WHERE updated_at IS NULL"
    );
    // 3. Rendi la colonna NOT NULL
    await queryInterface.changeColumn('refresh_tokens', 'updated_at', {
      type: Sequelize.DATE,
      allowNull: false,
      defaultValue: Sequelize.literal('CURRENT_TIMESTAMP')
    });
  },
  down: async (queryInterface, Sequelize) => {
    await queryInterface.removeColumn('refresh_tokens', 'updated_at');
  }
};
