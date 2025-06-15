/* eslint-env jest */
require('dotenv').config({ path: '.env.test' });
const request              = require('supertest');
const { sequelize, Spot } = require('../../models');
const app                  = require('../../app');      // punta ad app.js, non index.js
const { seedUser }         = require('../helpers/db');

let token;

beforeAll(async () => {
  await sequelize.sync({ force: true });
  token = await seedUser();

  // semina un paio di spot SENZA specificare l'id
  await Spot.bulkCreate([
    {
      userId:    'u1',
      name:      'Camping A',
      latitude:   44.53,
      longitude:  10.93,
      type:      'gratuito',
      services:  ['wifi'],
      features:  ['panoramic'],
      accessible:true,
      public:    true
    },
    {
      userId:    'u1',
      name:      'Camping B',
      latitude:   45,
      longitude:  10,
      type:      'gratuito',
      services:  ['wifi'],
      features:  ['panoramic'],
      accessible:true,
      public:    true
    }
  ]);
});

afterAll(async () => {
  await sequelize.close();
});

describe('GET /recommended-spots', () => {
  test('❌ senza token → 401', async () => {
    const res = await request(app)
      .get('/recommended-spots?latitude=44.5&longitude=10.9');
    expect(res.statusCode).toBe(401);
    expect(res.body).toHaveProperty('error', 'Token mancante');
  });

  test('✅ con token → lista spot', async () => {
    const res = await request(app)
      .get('/recommended-spots?latitude=44.5&longitude=10.9&distance=100')
      .set('Authorization', `Bearer ${token}`);
    expect(res.statusCode).toBe(200);
    expect(Array.isArray(res.body.spots)).toBe(true);
    expect(res.body.spots.length).toBeGreaterThan(0);

    // verifichiamo che ogni spot abbia un id generato (UUID)
    for (const spot of res.body.spots) {
      expect(spot).toHaveProperty('id', expect.any(String));
    }
  });

  test('✅ rispetta limit', async () => {
    const res = await request(app)
      .get('/recommended-spots?latitude=44.5&longitude=10.9&distance=100&limit=1')
      .set('Authorization', `Bearer ${token}`);
    expect(res.statusCode).toBe(200);
    expect(res.body.spots.length).toBeLessThanOrEqual(1);
  });
});
