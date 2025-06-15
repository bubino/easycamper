/* eslint-env jest */
const request = require('supertest');
const app     = require('../../app');
const { sequelize } = require('../../models');

let token, vehicleId;

beforeAll(async () => {
  await sequelize.sync({ force: true });

  await request(app).post('/auth/register')
    .send({ username: 't1', password: 'p' });

  const { body } = await request(app).post('/auth/login')
    .send({ username: 't1', password: 'p' });

  token = body.accessToken;

  const v = await request(app)
    .post('/vehicles')
    .set('Authorization', `Bearer ${token}`)
    .send({ type: 'camper', make: 'X', model: 'Y' });

  vehicleId = v.body.id;
});

afterAll(() => sequelize.close());

describe('CamperSpec API', () => {
  it('POST /camper-specs → 201', async () => {
    const res = await request(app)
      .post('/camper-specs')
      .set('Authorization', `Bearer ${token}`)
      .send({
        vehicleId,
        height: 3.2,
        width: 2.1,
        length: 7.5,
        weight: 3500,
      });
    expect(res.statusCode).toBe(201);
    expect(res.body).toHaveProperty('vehicleId', vehicleId);
  });

  it('GET /camper-specs/:vehicleId → 200', async () => {
    const res = await request(app)
      .get(`/camper-specs/${vehicleId}`)
      .set('Authorization', `Bearer ${token}`);
    expect(res.statusCode).toBe(200);
    expect(res.body).toHaveProperty('height', 3.2);
  });
});