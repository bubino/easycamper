/* eslint-env jest */
const request = require('supertest');
const app     = require('../../app');
const { sequelize } = require('../../models');

let token, vehicleId;

beforeAll(async () => {
  await sequelize.sync();

  await request(app).post('/auth/register')
    .send({ username: 't1', email: 't1@example.com', password: 'p' });

  // Verifica email
  const { User } = require('../../models');
  const jwt = require('jsonwebtoken');
  const user = await User.findOne({ where: { email: 't1@example.com' } });
  const verificationToken = jwt.sign({ id: user.id }, process.env.JWT_SECRET || 'testsecret', { expiresIn: '1d' });
  await request(app).get(`/auth/verify-email?token=${verificationToken}`);

  const loginRes = await request(app).post('/auth/login')
    .send({ email: 't1@example.com', password: 'p' });

  if (!loginRes.body || !loginRes.body.token) {
    throw new Error('Login fallita nei test: token JWT non ricevuto. Risposta: ' + JSON.stringify(loginRes.body));
  }
  token = loginRes.body.token;

  const v = await request(app)
    .post('/vehicles')
    .set('Authorization', `Bearer ${token}`)
    .send({ type: 'camper', make: 'XX', model: 'Y' }); // make ora ha almeno 2 caratteri

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
    // Se la validazione fallisce, mostra l'errore
    if (res.statusCode === 400) {
      console.error('Dettagli errore validazione:', res.body);
    }
    expect(res.statusCode).toBe(201);
    expect(res.body).toHaveProperty('vehicleId', vehicleId);
  });

  it('GET /camper-specs/:vehicleId → 200', async () => {
    const res = await request(app)
      .get(`/camper-specs/${vehicleId}`)
      .set('Authorization', `Bearer ${token}`);
    // Se la ricerca fallisce, mostra l'errore
    if (res.statusCode === 404) {
      console.error('Spec non trovata:', res.body);
    }
    expect(res.statusCode).toBe(200);
    expect(res.body).toHaveProperty('height', 3.2);
  });
});