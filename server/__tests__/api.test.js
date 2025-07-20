/* __tests__/api.test.js */
const request   = require('supertest');
const app       = require('../app');           // punta a app.js
const { sequelize } = require('../models');
const jwt = require('jsonwebtoken');

let token;
let vehicleId;
let spotId;
let entryId;

beforeAll(async () => {
  // 1) ricrea schema pulito
  await sequelize.sync({ force: true });

  // 2) registra utente
  await request(app)
    .post('/auth/register')
    .send({ username: 'test', email: 'test@example.com', password: 'password' });

  // 3) verifica email
  const { User } = require('../models');
  const user = await User.findOne({ where: { email: 'test@example.com' } });
  const verificationToken = jwt.sign({ id: user.id }, process.env.JWT_SECRET || 'testsecret', { expiresIn: '1d' });
  await request(app)
    .get(`/auth/verify-email?token=${verificationToken}`);

  // 4) login
  const res = await request(app)
    .post('/auth/login')
    .send({ email: 'test@example.com', password: 'password' });

  token = res.body.token;
});

afterAll(async () => {
  await sequelize.close();
});

describe('Vehicles API', () => {
  it('GET /vehicles -> []', async () => {
    const res = await request(app)
      .get('/vehicles')
      .set('Authorization', `Bearer ${token}`);

    expect(res.statusCode).toBe(200);
    expect(res.body).toEqual([]);
  });

  it('POST /vehicles -> 201', async () => {
    const res = await request(app)
      .post('/vehicles')
      .set('Authorization', `Bearer ${token}`)
      .send({
        type:  'camper',
        make:  'Fiat',
        model: 'Ducato'
      });

    expect(res.statusCode).toBe(201);
    expect(res.body).toHaveProperty('id', expect.any(String));
    vehicleId = res.body.id;
  });

  it('GET /vehicles -> [una entry]', async () => {
    const res = await request(app)
      .get('/vehicles')
      .set('Authorization', `Bearer ${token}`);

    expect(res.statusCode).toBe(200);
    expect(res.body).toHaveLength(1);
    expect(res.body[0].id).toBe(vehicleId);
  });
});

describe('Spots API', () => {
  it('GET /spots -> []', async () => {
    const res = await request(app)
      .get('/spots')
      .set('Authorization', `Bearer ${token}`);

    expect(res.statusCode).toBe(200);
    expect(res.body).toEqual([]);
  });

  it('POST /spots -> 201', async () => {
    const payload = {
      name:        'Camping',
      description: 'Bel posto',
      latitude:     45.0,
      longitude:    7.0
    };
    const res = await request(app)
      .post('/spots')
      .set('Authorization', `Bearer ${token}`)
      .send(payload);

    expect(res.statusCode).toBe(201);
    expect(res.body).toHaveProperty('id', expect.any(String));
    expect(res.body).toMatchObject({ name: 'Camping' });
    spotId = res.body.id;
  });

  it('full CRUD on /spots/:id', async () => {
    // GET list
    let res = await request(app)
      .get('/spots')
      .set('Authorization', `Bearer ${token}`);
    expect(res.body).toHaveLength(1);

    // GET single
    res = await request(app)
      .get(`/spots/${spotId}`)
      .set('Authorization', `Bearer ${token}`);
    expect(res.statusCode).toBe(200);
    expect(res.body.id).toBe(spotId);

    // PUT
    res = await request(app)
      .put(`/spots/${spotId}`)
      .set('Authorization', `Bearer ${token}`)
      .send({ name: 'Camping Updated' });
    expect(res.statusCode).toBe(200);
    expect(res.body.name).toBe('Camping Updated');

    // DELETE
    res = await request(app)
      .delete(`/spots/${spotId}`)
      .set('Authorization', `Bearer ${token}`);
    expect(res.statusCode).toBe(204);

    // Conferma cancellazione
    res = await request(app)
      .get('/spots')
      .set('Authorization', `Bearer ${token}`);
    expect(res.body).toEqual([]);
  });
});

describe('MaintenanceEntry API', () => {
  beforeAll(async () => {
    // assicuriamoci di avere un veicolo
    await request(app)
      .post('/vehicles')
      .set('Authorization', `Bearer ${token}`)
      .send({
        type:  'van',
        make:  'Ford',
        model: 'Transit'
      });
  });

  it('GET /maintenance -> []', async () => {
    const res = await request(app)
      .get('/maintenance')
      .set('Authorization', `Bearer ${token}`);

    expect(res.statusCode).toBe(200);
    expect(res.body).toEqual([]);
  });

  it('POST /maintenance -> 201', async () => {
    const payload = {
      vehicleId,
      date:    '2025-01-01',
      type:    'tagliando',
      notes:   'Cambio olio'
    };
    const res = await request(app)
      .post('/maintenance')
      .set('Authorization', `Bearer ${token}`)
      .send(payload);

    expect(res.statusCode).toBe(201);
    expect(res.body).toHaveProperty('id', expect.any(String));
    entryId = res.body.id;
  });

  it('full CRUD on /maintenance/:id', async () => {
    let res = await request(app)
      .get('/maintenance')
      .set('Authorization', `Bearer ${token}`);
    expect(res.body).toHaveLength(1);
    expect(res.body[0].id).toBe(entryId);

    // GET single
    res = await request(app)
      .get(`/maintenance/${entryId}`)
      .set('Authorization', `Bearer ${token}`);
    expect(res.statusCode).toBe(200);
    expect(res.body.id).toBe(entryId);

    // PUT
    res = await request(app)
      .put(`/maintenance/${entryId}`)
      .set('Authorization', `Bearer ${token}`)
      .send({ notes: 'Filtro aria' });
    expect(res.statusCode).toBe(200);
    expect(res.body.notes).toBe('Filtro aria');

    // DELETE
    res = await request(app)
      .delete(`/maintenance/${entryId}`)
      .set('Authorization', `Bearer ${token}`);
    expect(res.statusCode).toBe(204);

    // Conferma cancellazione
    res = await request(app)
      .get('/maintenance')
      .set('Authorization', `Bearer ${token}`);
    expect(res.body).toEqual([]);
  });
});
