'use strict';

module.exports = {
  up: async (queryInterface) => {
    await queryInterface.bulkInsert('Spots', [
      {
        id: 'spot1',
        name: 'Area Sosta Milano Nord',
        short_description: 'Area sosta attrezzata con servizi completi.',
        description:
          'Area sosta attrezzata con elettricità, acqua, scarico e videosorveglianza. Ottima base per visitare Milano.',
        latitude: 45.47,
        longitude: 9.18,
        type: 'area_sosta',
        rating_average: 4.5,
        rating_count: 28,
        services: JSON.stringify({
          electricity: true,
          water: true,
          wc: true,
          showers: true,
          wifi: false,
          petsAllowed: true,
          wasteDisposal: true,
          blackWater: true,
        }),
        tags: JSON.stringify(['super_servizi', 'vicino_citta']),
        opening_hours: 'Sempre aperto',
        price_info: '25€/notte, servizi inclusi',
        last_update: new Date(),
        created_at: new Date(),
        updated_at: new Date(),
      },
      {
        id: 'spot2',
        name: 'Campeggio Navigli',
        short_description: 'Campeggio immerso nel verde vicino ai Navigli.',
        description:
          'Campeggio immerso nel verde, piazzole grandi, ristorante interno, market e area giochi per bambini.',
        latitude: 45.4642,
        longitude: 9.19,
        type: 'campeggio',
        rating_average: 4.7,
        rating_count: 54,
        services: JSON.stringify({
          electricity: true,
          water: true,
          wc: true,
          showers: true,
          wifi: true,
          petsAllowed: true,
          laundry: true,
        }),
        tags: JSON.stringify(['panoramico', 'family_friendly']),
        opening_hours: 'Aprile - Ottobre',
        price_info: 'Da 35€/notte, bambini sconto 50%',
        last_update: new Date(),
        created_at: new Date(),
        updated_at: new Date(),
      },
      {
        id: 'spot3',
        name: 'Area Sosta Centro Storico',
        short_description: 'Area sosta vicina al centro, ideale per visite brevi.',
        description:
          'Area sosta vicina al centro, accesso 24h, bagni puliti, ottima per visitare la città a piedi.',
        latitude: 45.465,
        longitude: 9.192,
        type: 'area_sosta',
        rating_average: 4.2,
        rating_count: 19,
        services: JSON.stringify({
          electricity: true,
          water: true,
          wc: true,
          showers: false,
          wifi: false,
          petsAllowed: true,
        }),
        tags: JSON.stringify(['vicino_citta', 'tappa_veloce']),
        opening_hours: 'Sempre aperto',
        price_info: '20€/notte',
        last_update: new Date(),
        created_at: new Date(),
        updated_at: new Date(),
      },
    ]);
  },

  down: async (queryInterface) => {
    await queryInterface.bulkDelete('Spots', {
      id: ['spot1', 'spot2', 'spot3'],
    });
  },
};
