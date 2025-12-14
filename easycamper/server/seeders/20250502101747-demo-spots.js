'use strict';
module.exports = {
  up: async (queryInterface) => {
    await queryInterface.bulkInsert('Spots', [
      { id: 's_demo1', userId: 'u_demo1', name: 'Lago Demo', description: 'Area demo', latitude: 45.1, longitude: 7.1 },
      // ...
    ]);
  },
  down: async (queryInterface) => {
    await queryInterface.bulkDelete('Spots', { userId: 'u_demo1' });
  }
};
