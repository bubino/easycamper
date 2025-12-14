/* eslint-env jest */
require('dotenv').config({ path: '.env.test' });
const request              = require('supertest');
const { sequelize, Spot } = require('../../models');
const app                  = require('../../app');      // punta ad app.js, non index.js
const { seedUser }         = require('../helpers/db');

let token, userId;

beforeAll(async () => {
  await sequelize.sync();

  // registra utente con email, username, password
  const res = await request(app)
    .post('/auth/register')
    .send({ username: 'u1', email: 'u1@example.com', password: 'testpass' });
  userId = res.body.id;

  // Verifica email
  const { User } = require('../../models');
  const jwt = require('jsonwebtoken');
  const user = await User.findOne({ where: { email: 'u1@example.com' } });
  const verificationToken = jwt.sign({ id: user.id }, process.env.JWT_SECRET || 'testsecret', { expiresIn: '1d' });
  await request(app).get(`/auth/verify-email?token=${verificationToken}`);

  // login e prendi il token
  const loginRes = await request(app)
    .post('/auth/login')
    .send({ email: 'u1@example.com', password: 'testpass' });
  if (!loginRes.body || !loginRes.body.token) {
    throw new Error('Login fallita nei test: token JWT non ricevuto. Risposta: ' + JSON.stringify(loginRes.body));
  }
  token = loginRes.body.token;

  // semina un paio di spot usando l'id reale dell'utente
  await Spot.bulkCreate([
    {
      userId,
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
      userId,
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
