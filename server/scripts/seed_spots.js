'use strict';

const db = require('../models');

const spots = [
  { name: 'Area sosta Milano Nord', latitude: 45.52, longitude: 9.24, type: 'area_sosta' },
  { name: 'Parcheggio camper Milano Ovest', latitude: 45.46, longitude: 9.08, type: 'area_sosta' },
  { name: 'Area sosta Torino', latitude: 45.07, longitude: 7.69, type: 'area_sosta' },
  { name: 'Campeggio Lago Maggiore', latitude: 45.96, longitude: 8.64, type: 'campeggio' },
  { name: 'Area sosta Genova', latitude: 44.41, longitude: 8.93, type: 'area_sosta' },
  { name: 'Area sosta Bologna', latitude: 44.50, longitude: 11.34, type: 'area_sosta' },
  { name: 'Campeggio Firenze', latitude: 43.78, longitude: 11.25, type: 'campeggio' },
  { name: 'Area sosta Pisa', latitude: 43.72, longitude: 10.40, type: 'area_sosta' },
  { name: 'Area sosta Roma Est', latitude: 41.91, longitude: 12.58, type: 'area_sosta' },
  { name: 'Area sosta Roma Ovest', latitude: 41.89, longitude: 12.42, type: 'area_sosta' },
  { name: 'Campeggio Napoli', latitude: 40.85, longitude: 14.27, type: 'campeggio' },
  { name: 'Area sosta Bari', latitude: 41.12, longitude: 16.87, type: 'area_sosta' },
  { name: 'Agricampeggio Salento', latitude: 40.35, longitude: 18.17, type: 'agricampeggio' },
  { name: 'Area sosta Palermo', latitude: 38.12, longitude: 13.36, type: 'area_sosta' },
  { name: 'Campeggio Catania', latitude: 37.51, longitude: 15.09, type: 'campeggio' },
  { name: 'Area sosta Cagliari', latitude: 39.22, longitude: 9.12, type: 'area_sosta' },
  { name: 'Area sosta Verona', latitude: 45.44, longitude: 10.99, type: 'area_sosta' },
  { name: 'Campeggio Venezia', latitude: 45.44, longitude: 12.33, type: 'campeggio' },
  { name: 'Area sosta Trieste', latitude: 45.65, longitude: 13.78, type: 'area_sosta' },
  { name: 'Agricampeggio Umbria', latitude: 43.11, longitude: 12.39, type: 'agricampeggio' },

  // Extra density (5-10 POIs) for clustering tests
  // Milano
  { name: 'Area sosta Milano Centro (seed)', latitude: 45.4641, longitude: 9.1919, type: 'area_sosta' },
  { name: 'Area sosta Milano Sud (seed)', latitude: 45.4370, longitude: 9.2100, type: 'area_sosta' },
  { name: 'Area sosta Milano Est (seed)', latitude: 45.4685, longitude: 9.2600, type: 'area_sosta' },
  { name: 'Campeggio Milano (seed)', latitude: 45.5070, longitude: 9.1450, type: 'campeggio' },
  { name: 'Parcheggio camper Milano Nord-Est (seed)', latitude: 45.5050, longitude: 9.2350, type: 'area_sosta' },

  // Roma
  { name: 'Area sosta Roma Centro (seed)', latitude: 41.9028, longitude: 12.4964, type: 'area_sosta' },
  { name: 'Area sosta Roma Sud (seed)', latitude: 41.8460, longitude: 12.5030, type: 'area_sosta' },
  { name: 'Area sosta Roma Nord (seed)', latitude: 41.9500, longitude: 12.5000, type: 'area_sosta' },
  { name: 'Campeggio Roma (seed)', latitude: 41.9300, longitude: 12.4060, type: 'campeggio' },
  { name: 'Parcheggio camper Roma Est (seed)', latitude: 41.9100, longitude: 12.6100, type: 'area_sosta' },

  // Napoli
  { name: 'Area sosta Napoli Centro (seed)', latitude: 40.8518, longitude: 14.2681, type: 'area_sosta' },
  { name: 'Area sosta Napoli Ovest (seed)', latitude: 40.8270, longitude: 14.1750, type: 'area_sosta' },
  { name: 'Area sosta Napoli Est (seed)', latitude: 40.8600, longitude: 14.3300, type: 'area_sosta' },
  { name: 'Campeggio Napoli Nord (seed)', latitude: 40.9020, longitude: 14.2400, type: 'campeggio' },
  { name: 'Parcheggio camper Napoli Porto (seed)', latitude: 40.8400, longitude: 14.2750, type: 'area_sosta' },

  // Torino
  { name: 'Area sosta Torino Centro (seed)', latitude: 45.0703, longitude: 7.6869, type: 'area_sosta' },
  { name: 'Area sosta Torino Nord (seed)', latitude: 45.1000, longitude: 7.6900, type: 'area_sosta' },
  { name: 'Area sosta Torino Sud (seed)', latitude: 45.0300, longitude: 7.6600, type: 'area_sosta' },
  { name: 'Campeggio Torino (seed)', latitude: 45.0850, longitude: 7.6200, type: 'campeggio' },
  { name: 'Parcheggio camper Torino Est (seed)', latitude: 45.0650, longitude: 7.7400, type: 'area_sosta' },

  // Bologna
  { name: 'Area sosta Bologna Centro (seed)', latitude: 44.4949, longitude: 11.3426, type: 'area_sosta' },
  { name: 'Area sosta Bologna Nord (seed)', latitude: 44.5350, longitude: 11.3400, type: 'area_sosta' },
  { name: 'Area sosta Bologna Sud (seed)', latitude: 44.4500, longitude: 11.3600, type: 'area_sosta' },
  { name: 'Campeggio Bologna (seed)', latitude: 44.5200, longitude: 11.2800, type: 'campeggio' },
  { name: 'Parcheggio camper Bologna Est (seed)', latitude: 44.5000, longitude: 11.4200, type: 'area_sosta' },

  // Firenze
  { name: 'Area sosta Firenze Centro (seed)', latitude: 43.7696, longitude: 11.2558, type: 'area_sosta' },
  { name: 'Area sosta Firenze Nord (seed)', latitude: 43.8050, longitude: 11.2500, type: 'area_sosta' },
  { name: 'Area sosta Firenze Sud (seed)', latitude: 43.7350, longitude: 11.2700, type: 'area_sosta' },
  { name: 'Campeggio Firenze (seed 2)', latitude: 43.7900, longitude: 11.1900, type: 'campeggio' },
  { name: 'Parcheggio camper Firenze Ovest (seed)', latitude: 43.7750, longitude: 11.1700, type: 'area_sosta' },
];

function servicesForType(type) {
  if (type === 'campeggio') {
    return { water: true, electricity: true, toilet_public: true, showers: true, trash: true, wifi: true };
  }
  if (type === 'agricampeggio') {
    return { water: true, electricity: true, trash: true, animals: true };
  }
  return { water: true, electricity: true, trash: true };
}

(async () => {
  try {
    await db.sequelize.authenticate();

    const user = await db.User.findOne();
    if (!user) {
      console.error('No users found. Create a user first, then run seed:spots.');
      process.exit(1);
    }

    const userId = user.id;

    let created = 0;
    for (const s of spots) {
      const existing = await db.Spot.findOne({
        where: {
          name: s.name,
          latitude: s.latitude,
          longitude: s.longitude,
        },
      });

      if (existing) continue;

      await db.Spot.create({
        userId,
        name: s.name,
        latitude: s.latitude,
        longitude: s.longitude,
        type: s.type,
        shortDescription: 'Spot di esempio per sviluppo (seed).',
        services: servicesForType(s.type),
        ratingAverage: 4.2,
        ratingCount: 10,
      });
      created++;
    }

    console.log(`Seed complete. Created ${created} spots (skipped duplicates).`);
    process.exit(0);
  } catch (e) {
    console.error('Seed failed:', e);
    process.exit(1);
  }
})();
