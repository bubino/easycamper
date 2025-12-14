'use strict';
module.exports = {
  up: async (qi) => {
    await qi.bulkInsert('MaintenanceEntries', [
      { id: 'm_demo1', vehicleId: 'v_demo1', date: '2025-05-01', type: 'controllo', notes: 'Demo check', createdAt: new Date(), updatedAt: new Date() }
    ]);
  },
  down: async (qi) => {
    await qi.bulkDelete('MaintenanceEntries', { vehicleId: 'v_demo1' });
  }
};
