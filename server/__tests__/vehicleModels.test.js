const request = require('supertest');
const app = require('../app');
const db = require('../easycamper/server/models');

const { VehicleModel } = db;

// Seed minimale per i test (coerente con vehicle_models.json ma ristretto)
const seedModels = [
  {
    id: '00000000-0000-0000-0000-000000000001',
    brand: 'Fiat',
    model: 'Ducato Test 1',
    year_from: 2015,
    length_m: 5.4,
    height_m: 2.5,
    weight_kg: 3000,
    type: 'van',
    brand_slug: 'fiat',
  },
  {
    id: '00000000-0000-0000-0000-000000000002',
    brand: 'Fiat',
    model: 'Ducato Test 2',
    year_from: 2016,
    length_m: 6.0,
    height_m: 2.7,
    weight_kg: 3300,
    type: 'van',
    brand_slug: 'fiat',
  },
  {
    id: '00000000-0000-0000-0000-000000000003',
    brand: 'Volkswagen',
    model: 'California Test',
    year_from: 2018,
    length_m: 4.9,
    height_m: 2.0,
    weight_kg: 3000,
    type: 'camper',
    brand_slug: 'volkswagen',
  },
];

beforeAll(async () => {
  await db.sequelize.sync({ force: true });
  await VehicleModel.bulkCreate(seedModels);
});

afterAll(async () => {
  await db.sequelize.close();
});

describe('GET /api/vehicle-models', () => {
  test('restituisce lista completa con struttura paginata', async () => {
    const res = await request(app).get('/api/vehicle-models').expect(200);

    expect(res.body).toHaveProperty('data');
    expect(res.body).toHaveProperty('total', seedModels.length);
    expect(res.body).toHaveProperty('limit');
    expect(res.body).toHaveProperty('offset');

    expect(Array.isArray(res.body.data)).toBe(true);
    expect(res.body.data.length).toBe(seedModels.length);
    const item = res.body.data[0];
    expect(item).toHaveProperty('brand');
    expect(item).toHaveProperty('model');
    expect(item).toHaveProperty('year_from');
    expect(item).toHaveProperty('length_m');
    expect(item).toHaveProperty('height_m');
    expect(item).toHaveProperty('weight_kg');
    expect(item).toHaveProperty('type');
    expect(item).toHaveProperty('brand_slug');
  });

  test('filtra per search (brand+model)', async () => {
    const res = await request(app)
      .get('/api/vehicle-models')
      .query({ search: 'ducato' })
      .expect(200);

    expect(res.body.total).toBe(2);
    const brands = res.body.data.map(m => m.brand);
    expect(new Set(brands)).toEqual(new Set(['Fiat']));
  });

  test('filtra per brand', async () => {
    const res = await request(app)
      .get('/api/vehicle-models')
      .query({ brand: 'volkswagen' })
      .expect(200);

    expect(res.body.total).toBe(1);
    expect(res.body.data[0].brand_slug).toBe('volkswagen');
  });

  test('applica limit e offset', async () => {
    const res1 = await request(app)
      .get('/api/vehicle-models')
      .query({ limit: 1, offset: 0 })
      .expect(200);

    expect(res1.body.data.length).toBe(1);
    expect(res1.body.limit).toBe(1);
    expect(res1.body.offset).toBe(0);

    const res2 = await request(app)
      .get('/api/vehicle-models')
      .query({ limit: 1, offset: 1 })
      .expect(200);

    expect(res2.body.data.length).toBe(1);
    expect(res2.body.offset).toBe(1);
    expect(res1.body.data[0].id).not.toBe(res2.body.data[0].id);
  });
});
