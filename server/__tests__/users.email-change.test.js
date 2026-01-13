const request = require('supertest');
const app = require('../app');
const db = require('../models');

const { User, AuditLog } = db;

beforeAll(async () => {
  await db.sequelize.sync({ force: true });
});

afterAll(async () => {
  await db.sequelize.close();
});

describe('User email change flow', () => {
  let user;

  beforeEach(async () => {
    await AuditLog.destroy({ where: {} });
    await User.destroy({ where: {} });

    user = await User.create({
      id: '11111111-1111-1111-1111-111111111111',
      username: 'testuser',
      email: 'old@example.com',
      password: 'password',
      emailVerified: true,
    });
  });

  test('POST /users/:id/change-email - richiede newEmail valida', async () => {
    const res1 = await request(app)
      .post(`/users/${user.id}/change-email`)
      .send({})
      .expect(400);
    expect(res1.body.error).toMatch(/Nuova email richiesta/);

    const res2 = await request(app)
      .post(`/users/${user.id}/change-email`)
      .send({ newEmail: 'not-an-email' })
      .expect(400);
    expect(res2.body.error).toMatch(/Nuova email non valida/);
  });

  test('POST /users/:id/change-email - utente non trovato', async () => {
    await User.destroy({ where: {} });
    const res = await request(app)
      .post('/users/22222222-2222-2222-2222-222222222222/change-email')
      .send({ newEmail: 'new@example.com' })
      .expect(404);
    expect(res.body.error).toMatch(/Utente non trovato/);
  });

  test('POST /users/:id/change-email - nuova email uguale alla attuale', async () => {
    const res = await request(app)
      .post(`/users/${user.id}/change-email`)
      .send({ newEmail: 'old@example.com' })
      .expect(400);
    expect(res.body.error).toMatch(/coincide con quella attuale/);
  });

  test('POST /users/:id/change-email - successo genera token e AuditLog', async () => {
    const res = await request(app)
      .post(`/users/${user.id}/change-email`)
      .send({ newEmail: 'new@example.com' })
      .expect(200);

    expect(res.body.message).toMatch(/Richiesta cambio email ricevuta/);

    const updated = await User.findByPk(user.id);
    expect(updated.emailChangeToken).toBeTruthy();
    expect(updated.emailChangeNew).toBe('new@example.com');
    expect(updated.emailChangeRequestedAt).toBeTruthy();

    const logs = await AuditLog.findAll({ where: { userId: user.id, operation: 'request_email_change' } });
    expect(logs.length).toBe(1);
  });

  test('GET /users/confirm-email-change - token mancante', async () => {
    const res = await request(app)
      .get('/users/confirm-email-change')
      .expect(400);
    expect(res.body.error).toMatch(/Token mancante/);
  });

  test('GET /users/confirm-email-change - token inesistente o già usato', async () => {
    const res = await request(app)
      .get('/users/confirm-email-change')
      .query({ token: 'nonexistent' })
      .expect(400);
    expect(res.body.error).toMatch(/Token non valido o già usato/);
  });

  test('GET /users/confirm-email-change - token scaduto', async () => {
    user.emailChangeToken = 'expiredtoken';
    user.emailChangeNew = 'new@example.com';
    const pastDate = new Date(Date.now() - 25 * 60 * 60 * 1000);
    user.emailChangeRequestedAt = pastDate;
    await user.save();

    const res = await request(app)
      .get('/users/confirm-email-change')
      .query({ token: 'expiredtoken' })
      .expect(400);

    expect(res.body.error).toMatch(/Token scaduto/);

    const refreshed = await User.findByPk(user.id);
    expect(refreshed.emailChangeToken).toBeNull();
    expect(refreshed.emailChangeNew).toBeNull();
    expect(refreshed.emailChangeRequestedAt).toBeNull();
  });

  test('GET /users/confirm-email-change - successo aggiorna email, resetta flag e logga', async () => {
    user.emailChangeToken = 'validtoken';
    user.emailChangeNew = 'new@example.com';
    user.emailChangeRequestedAt = new Date();
    await user.save();

    const res = await request(app)
      .get('/users/confirm-email-change')
      .query({ token: 'validtoken' })
      .expect(200);

    expect(res.body.message).toMatch(/Cambio email confermato/);

    const updated = await User.findByPk(user.id);
    expect(updated.email).toBe('new@example.com');
    expect(updated.emailVerified).toBe(false);
    expect(updated.emailChangeToken).toBeNull();
    expect(updated.emailChangeNew).toBeNull();
    expect(updated.emailChangeRequestedAt).toBeNull();

    const logs = await AuditLog.findAll({ where: { userId: user.id, operation: 'change_email' } });
    expect(logs.length).toBe(1);
  });
});
