'use strict';

module.exports = {
  async up (queryInterface, Sequelize) {
    await queryInterface.bulkInsert('Vehicles', [
      {
        id: 'v_demo1',
        userId: 'u_demo1',
        type: 'camper',
        make: 'Fiat',
        model: 'Ducato',
        createdAt: new Date(),
        updatedAt: new Date()
      },
      {
        id: 'v_demo2',
        userId: 'u_demo2',
        type: 'van',
        make: 'VW',
        model: 'California',
        createdAt: new Date(),
        updatedAt: new Date()
      }
    ], {});
  },

  async down (queryInterface, Sequelize) {
    await queryInterface.bulkDelete('Vehicles', {
      id: { [Sequelize.Op.in]: ['v_demo1','v_demo2'] }
    }, {});
  }
};
