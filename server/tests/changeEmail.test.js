const request = require('supertest');
const app = require('../app');
const { sequelize, User } = require('../models');
const jwt = require('jsonwebtoken');

describe('Cambio email utente', () => {
  let userId, oldEmail, newEmail, token;

  beforeAll(async () => {
    await sequelize.sync();
    oldEmail = 'changeemail@example.com';
    newEmail = 'changed@example.com';
    // Registra utente
    await request(app)
      .post('/auth/register')
      .send({ username: 'changeuser', email: oldEmail, password: 'Password123!' });
    const user = await User.findOne({ where: { email: oldEmail } });
    userId = user.id;
    // Verifica email
    const verificationToken = jwt.sign({ id: user.id }, process.env.JWT_SECRET || 'testsecret', { expiresIn: '1d' });
    await request(app).get(`/auth/verify-email?token=${verificationToken}`);
    // Login
    const loginRes = await request(app)
      .post('/auth/login')
      .send({ email: oldEmail, password: 'Password123!' });
    token = loginRes.body.token;
  });

  it('richiede cambio email e conferma', async () => {
    // Richiesta cambio email
    const res = await request(app)
      .post(`/users/${userId}/change-email`)
      .set('Authorization', `Bearer ${token}`)
      .send({ newEmail });
    expect(res.statusCode).toBe(200);
    expect(res.body.message).toMatch(/Richiesta cambio email/);

    // Recupera token di conferma dal db subito dopo la richiesta
    const user = await User.findByPk(userId);
    const emailChangeToken = user.emailChangeToken;
    // Verifica token e nuova email
    expect(emailChangeToken).toBeTruthy();
    expect(user.emailChangeNew).toBe(newEmail);

    // Conferma cambio email usando il token appena generato
    const confirmRes = await request(app)
      .get(`/users/confirm-email-change?token=${emailChangeToken}`);
    expect(confirmRes.statusCode).toBe(200);
    expect(confirmRes.body.message).toMatch(/Cambio email confermato/);

    // Verifica che l'email sia cambiata
    const updatedUser = await User.findByPk(userId);
    expect(updatedUser.email).toBe(newEmail);
    expect(updatedUser.emailVerified).toBe(false);
    expect(updatedUser.emailChangeToken).toBeNull();
    expect(updatedUser.emailChangeNew).toBeNull();
    expect(updatedUser.emailChangeRequestedAt).toBeNull();

    // Login con vecchia email deve fallire
    const oldLogin = await request(app)
      .post('/auth/login')
      .send({ email: oldEmail, password: 'Password123!' });
    expect(oldLogin.statusCode).toBe(404);

    // Login con nuova email deve essere bloccato finché non verificata
    const newLogin = await request(app)
      .post('/auth/login')
      .send({ email: newEmail, password: 'Password123!' });
    expect(newLogin.statusCode).toBe(403);
    expect(newLogin.body.error).toMatch(/Email non verificata/);
  });
});
