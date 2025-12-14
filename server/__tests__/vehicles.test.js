const request = require('supertest');
const app = require('../app');
const { Vehicle, User } = require('../models');
let token, userId, vehicleId;

describe('CRUD Veicoli', () => {
  beforeAll(async () => {
    // Crea utente di test e ottieni token
    const user = await User.create({ email: 'testvehicle@example.com', password: 'testpass', username: 'testvehicle' });
    userId = user.id;
    // Simula login per ottenere JWT
    token = 'Bearer ' + require('../createToken')(user); // funzione che crea JWT
  });

  afterAll(async () => {
    await Vehicle.destroy({ where: { userId } });
    await User.destroy({ where: { id: userId } });
  });

  test('POST /vehicles - crea veicolo valido', async () => {
    const res = await request(app)
      .post('/vehicles')
      .set('Authorization', token)
      .send({ type: 'camper', make: 'Fiat', model: 'Ducato', year: 2020 });
    expect(res.statusCode).toBe(201);
    expect(res.body.type).toBe('camper');
    vehicleId = res.body.id;
  });

  test('POST /vehicles - validazione: tipo non valido', async () => {
    const res = await request(app)
      .post('/vehicles')
      .set('Authorization', token)
      .send({ type: 'bike', make: 'Yamaha', model: 'XT' });
    expect(res.statusCode).toBe(400);
    expect(res.body.errors).toBeDefined();
  });

  test('GET /vehicles - lista veicoli utente', async () => {
    const res = await request(app)
      .get('/vehicles')
      .set('Authorization', token);
    expect(res.statusCode).toBe(200);
    expect(Array.isArray(res.body)).toBe(true);
    expect(res.body.length).toBeGreaterThan(0);
  });

  test('PUT /vehicles/:id - modifica veicolo', async () => {
    const res = await request(app)
      .put(`/vehicles/${vehicleId}`)
      .set('Authorization', token)
      .send({ make: 'Citroen', model: 'Jumper', type: 'van', year: 2021 });
    expect(res.statusCode).toBe(200);
    expect(res.body.make).toBe('Citroen');
    expect(res.body.type).toBe('van');
  });

  test('PUT /vehicles/:id - validazione: anno fuori range', async () => {
    const res = await request(app)
      .put(`/vehicles/${vehicleId}`)
      .set('Authorization', token)
      .send({ year: 1900 });
    expect(res.statusCode).toBe(400);
    expect(res.body.errors).toBeDefined();
  });

  test('DELETE /vehicles/:id - cancella veicolo', async () => {
    const res = await request(app)
      .delete(`/vehicles/${vehicleId}`)
      .set('Authorization', token);
    expect(res.statusCode).toBe(204);
  });

  test('DELETE /vehicles/:id - veicolo non trovato', async () => {
    const res = await request(app)
      .delete(`/vehicles/${vehicleId}`)
      .set('Authorization', token);
    expect(res.statusCode).toBe(404);
  });
});
