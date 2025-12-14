const request = require('supertest');
const app = require('../app');
const { sequelize, Spot } = require('../models');

describe('GET /spots', () => {
  beforeAll(async () => {
    await sequelize.sync();
    await Spot.destroy({ where: {} });
    await Spot.bulkCreate([
      {
        name: 'Area Sosta Milano Nord',
        shortDescription: 'Area sosta attrezzata',
        latitude: 45.47,
        longitude: 9.18,
        type: 'area_sosta',
        ratingAverage: 4.5,
        ratingCount: 10,
        services: { electricity: true, water: true },
      },
    ]);
  });

  afterAll(async () => {
    await sequelize.close();
  });

  it('restituisce spot dentro la bbox', async () => {
    const res = await request(app)
      .get('/spots')
      .query({ bbox: '45.0,9.0,46.0,10.0' })
      .expect(200);

    expect(res.body.spots.length).toBeGreaterThan(0);
    expect(res.body.spots[0]).toHaveProperty('id');
    expect(res.body.spots[0]).toHaveProperty('name');
  });

  it('valida bbox mancante', async () => {
    const res = await request(app).get('/spots').expect(400);
    expect(res.body.error).toBeDefined();
  });
});

describe('GET /spots/:id', () => {
  let spot;

  beforeAll(async () => {
    await sequelize.sync();
    spot = await Spot.create({
      name: 'Spot Dettaglio Test',
      latitude: 45.5,
      longitude: 9.2,
    });
  });

  afterAll(async () => {
    await sequelize.close();
  });

  it('restituisce 404 per id inesistente', async () => {
    const res = await request(app).get('/spots/non-esiste').expect(404);
    expect(res.body.error).toBeDefined();
  });

  it('restituisce il dettaglio spot', async () => {
    const res = await request(app).get(`/spots/${spot.id}`).expect(200);
    expect(res.body.id).toBe(spot.id);
    expect(res.body.name).toBe('Spot Dettaglio Test');
  });
});