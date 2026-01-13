const request = require('supertest');
const app = require('../app');
const { sequelize, Spot, User } = require('../models');

// Use a unique sqlite file per test worker to prevent cross-suite interference.
beforeAll(async () => {
  await sequelize.sync({ force: true });
});

afterAll(async () => {
  // Do not close sequelize here: other test files may still be running.
});

describe('GET /spots', () => {
  let user;

  beforeAll(async () => {
    await Spot.destroy({ where: {} });
    await User.destroy({ where: {} });

    user = await User.create({
      id: '33333333-3333-3333-3333-333333333333',
      username: 'spots-seed-user',
      email: 'spots-seed@example.com',
      password: 'password',
      emailVerified: true,
    });

    await Spot.bulkCreate([
      {
        userId: user.id,
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

  it('restituisce spot dentro la bbox', async () => {
    const res = await request(app)
      .get('/spots')
      .set('Authorization', 'Bearer validToken')
      .query({ bbox: '45.0,9.0,46.0,10.0' })
      .expect(200);

    expect(Array.isArray(res.body.spots)).toBe(true);
    expect(res.body.spots.length).toBeGreaterThan(0);
    expect(res.body.spots[0]).toHaveProperty('id');
    expect(res.body.spots[0]).toHaveProperty('name');
  });

  it('valida bbox mancante', async () => {
    const res = await request(app)
      .get('/spots')
      .set('Authorization', 'Bearer validToken')
      .expect(400);
    expect(res.body.error).toMatch(/bbox/i);
  });
});

describe('GET /spots/:id', () => {
  let spot;
  let user;

  beforeAll(async () => {
    await Spot.destroy({ where: {} });
    await User.destroy({ where: {} });

    user = await User.create({
      id: '44444444-4444-4444-4444-444444444444',
      username: 'spots-detail-user',
      email: 'spots-detail@example.com',
      password: 'password',
      emailVerified: true,
    });

    spot = await Spot.create({
      userId: user.id,
      name: 'Spot Dettaglio Test',
      latitude: 45.5,
      longitude: 9.2,
    });
  });

  it('restituisce 400 per id non valido (non UUID)', async () => {
    const res = await request(app)
      .get('/spots/non-esiste')
      .set('Authorization', 'Bearer validToken')
      .expect(400);
    expect(res.body.error).toBeDefined();
  });

  it('restituisce il dettaglio spot', async () => {
    const res = await request(app)
      .get(`/spots/${spot.id}`)
      .set('Authorization', 'Bearer validToken')
      .expect(200);
    expect(res.body.id).toBe(spot.id);
    expect(res.body.name).toBe('Spot Dettaglio Test');
  });
});