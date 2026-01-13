const request = require('supertest');
const app = require('../app');
const db = require('../models');

const { User, Vehicle, VehicleModel } = db;

beforeAll(async () => {
  await db.sequelize.sync({ force: true });
});

afterAll(async () => {
  await db.sequelize.close();
});

describe('Vehicles ↔ VehicleModels integration', () => {
  let user;
  let vm;
  let token;

  beforeEach(async () => {
    await Vehicle.destroy({ where: {} });
    await VehicleModel.destroy({ where: {} });
    await User.destroy({ where: {} });

    user = await User.create({
      id: '00000000-0000-0000-0000-000000000001',
      username: 'vehicle-test-user',
      email: 'vehicle@test.com',
      password: 'password',
    });

    // In test l'app decodifica solo il payload, ma verifica comunque la firma con JWT_SECRET (default: 'testsecret')
    token = require('jsonwebtoken').sign({ id: user.id }, process.env.JWT_SECRET || 'testsecret');

    vm = await VehicleModel.create({
      id: 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
      brand: 'Fiat',
      model: 'Ducato Test',
      year_from: 2020,
      length_m: 6.0,
      height_m: 2.8,
      weight_kg: 3500,
      type: 'van',
      brand_slug: 'fiat',
    });
  });

  function auth() {
    return { Authorization: `Bearer ${token}` };
  }

  test('POST /vehicles con vehicleModelId eredita length/height/weight se assenti', async () => {
    const res = await request(app)
      .post('/vehicles')
      .set(auth())
      .send({
        type: 'camper',
        make: 'Fiat',
        model: 'Ducato Derived',
        year: 2021,
        vehicleModelId: vm.id,
      })
      .expect(201);

    expect(res.body.vehicleModelId).toBe(vm.id);
    expect(res.body.length).toBeCloseTo(vm.length_m);
    expect(res.body.height).toBeCloseTo(vm.height_m);
    expect(res.body.weight).toBeCloseTo(vm.weight_kg);
  });

  test('POST /vehicles con vehicleModelId ma length/height/weight espliciti mantiene i valori manuali', async () => {
    const res = await request(app)
      .post('/vehicles')
      .set(auth())
      .send({
        type: 'camper',
        make: 'Fiat',
        model: 'Ducato Custom',
        year: 2021,
        vehicleModelId: vm.id,
        length: 7.0,
        height: 3.0,
        weight: 4000,
      })
      .expect(201);

    expect(res.body.vehicleModelId).toBe(vm.id);
    expect(res.body.length).toBe(7.0);
    expect(res.body.height).toBe(3.0);
    expect(res.body.weight).toBe(4000);
  });

  test('POST /vehicles con vehicleModelId inesistente restituisce 400', async () => {
    const res = await request(app)
      .post('/vehicles')
      .set(auth())
      .send({
        type: 'camper',
        make: 'Fiat',
        model: 'Ducato Invalid',
        year: 2021,
        vehicleModelId: 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
      })
      .expect(400);

    expect(res.body.error).toMatch(/vehicleModelId non valido/);
  });
});
