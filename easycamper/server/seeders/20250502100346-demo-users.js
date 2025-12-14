'use strict';

module.exports = {
  async up (queryInterface, Sequelize) {
    await queryInterface.bulkInsert('Users', [
      {
        id: 'u_demo1',
        username: 'alice',
        passwordHash: await (require('bcrypt').hash('password1', 10))
      },
      {
        id: 'u_demo2',
        username: 'bob',
        passwordHash: await (require('bcrypt').hash('password2', 10))
      }
    ], {});
  },

  async down (queryInterface, Sequelize) {
    await queryInterface.bulkDelete('Users', {
      id: { [Sequelize.Op.in]: ['u_demo1','u_demo2'] }
    }, {});
  }
};
