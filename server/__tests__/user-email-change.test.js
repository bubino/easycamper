const request = require('supertest');
const app = require('../app');
const { User } = require('../models');

describe('Cambio email utente', () => {
  let user;
  beforeAll(async () => {
    user = await User.create({
      username: 'testuser',
      email: 'old@example.com',
      password: 'Password123!'
    });
  });
  afterAll(async () => {
    await User.destroy({ where: { id: user.id } });
  });

  it('richiede cambio email e genera token', async () => {
    const res = await request(app)
      .post(`/users/${user.id}/change-email`)
      .send({ newEmail: 'new@example.com' });
    expect(res.status).toBe(200);
    expect(res.body.message).toMatch(/Richiesta cambio email/i);
    const updated = await User.findByPk(user.id);
    expect(updated.emailChangeToken).toBeTruthy();
    expect(updated.emailChangeNew).toBe('new@example.com');
  });

  it('conferma il cambio email con token valido', async () => {
    // Simula richiesta precedente
    const token = user.emailChangeToken || (await User.findByPk(user.id)).emailChangeToken;
    const res = await request(app)
      .get(`/users/confirm-email-change?token=${token}`);
    expect(res.status).toBe(200);
    expect(res.body.message).toMatch(/Cambio email confermato/i);
    const updated = await User.findByPk(user.id);
    expect(updated.email).toBe('new@example.com');
    expect(updated.emailChangeToken).toBeNull();
    expect(updated.emailChangeNew).toBeNull();
  });

  it('rifiuta token mancante o non valido', async () => {
    const res = await request(app)
      .get('/users/confirm-email-change?token=invalidtoken123');
    expect(res.status).toBe(400);
    expect(res.body.error).toMatch(/Token non valido/i);
  });
});
