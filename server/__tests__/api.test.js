// __tests__/api.test.js
const request = require('supertest');
const app     = require('../index.js');
const { sequelize } = require('../models');

let token;

beforeAll(async () => {
  // 1) ricrea schema
  await sequelize.sync({ force: true });

  // 2) registra e fai login una sola volta
  await request(app)
    .post('/auth/register')
    .send({ id: 't1', username: 'test', password: 'password' });

  const res = await request(app)
    .post('/auth/login')
    .send({ username: 'test', password: 'password' });

  token = res.body.accessToken;
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
      .send({ id:'v1', type:'camper', make:'Fiat', model:'Ducato' });
    expect(res.statusCode).toBe(201);
    expect(res.body).toHaveProperty('id','v1');
  });

  it('GET /vehicles -> [v1]', async () => {
    const res = await request(app)
      .get('/vehicles')
      .set('Authorization', `Bearer ${token}`);
    expect(res.body).toHaveLength(1);
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
    const payload = { id:'s1', name:'Camping', description:'Bel posto', latitude:45.0, longitude:7.0 };
    const res = await request(app)
      .post('/spots')
      .set('Authorization', `Bearer ${token}`)
      .send(payload);
    expect(res.statusCode).toBe(201);
    expect(res.body).toMatchObject({ id:'s1', name:'Camping' });
  });

  it('full CRUD on /spots/:id', async () => {
    // GET list
    let res = await request(app)
      .get('/spots')
      .set('Authorization', `Bearer ${token}`);
    expect(res.body).toHaveLength(1);

    // GET single
    res = await request(app)
      .get('/spots/s1')
      .set('Authorization', `Bearer ${token}`);
    expect(res.statusCode).toBe(200);

    // PUT
    res = await request(app)
      .put('/spots/s1')
      .set('Authorization', `Bearer ${token}`)
      .send({ name: 'Camping Updated' });
    expect(res.body.name).toBe('Camping Updated');

    // DELETE
    res = await request(app)
      .delete('/spots/s1')
      .set('Authorization', `Bearer ${token}`);
    expect(res.statusCode).toBe(204);

    // Confirm deletion
    res = await request(app)
      .get('/spots')
      .set('Authorization', `Bearer ${token}`);
    expect(res.body).toEqual([]);
  });
});

describe('MaintenanceEntry API', () => {
  beforeAll(async () => {
    // assicurati di avere un veicolo
    await request(app)
      .post('/vehicles')
      .set('Authorization', `Bearer ${token}`)
      .send({ id:'v2', type:'van', make:'Ford', model:'Transit' });
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
      id: 'm1',
      vehicleId: 'v2',
      date: '2025-01-01',
      type: 'tagliando',
      notes: 'Cambio olio'
    };
    const res = await request(app)
      .post('/maintenance')
      .set('Authorization', `Bearer ${token}`)
      .send(payload);
    expect(res.statusCode).toBe(201);
    expect(res.body).toHaveProperty('id','m1');
  });

  it('full CRUD on /maintenance/:id', async () => {
    let res = await request(app)
      .get('/maintenance')
      .set('Authorization', `Bearer ${token}`);
    expect(res.body).toHaveLength(1);

    res = await request(app)
      .get('/maintenance/m1')
      .set('Authorization', `Bearer ${token}`);
    expect(res.statusCode).toBe(200);

    res = await request(app)
      .put('/maintenance/m1')
      .set('Authorization', `Bearer ${token}`)
      .send({ notes: 'Filtro aria' });
    expect(res.body.notes).toBe('Filtro aria');

    res = await request(app)
      .delete('/maintenance/m1')
      .set('Authorization', `Bearer ${token}`);
    expect(res.statusCode).toBe(204);

    res = await request(app)
      .get('/maintenance')
      .set('Authorization', `Bearer ${token}`);
    expect(res.body).toEqual([]);
  });
});
