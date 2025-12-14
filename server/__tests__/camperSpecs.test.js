const request = require('supertest');
const app = require('../app');
const { Vehicle, CamperSpec, User } = require('../models');
let token, userId, vehicleId, specId;

describe('CRUD Specifiche Tecniche Camper', () => {
  beforeAll(async () => {
    // Crea utente di test e ottieni token
    const user = await User.create({ email: 'testspec@example.com', password: 'testpass' });
    userId = user.id;
    token = 'Bearer ' + require('../createToken')(user);
    // Crea veicolo associato
    const vehicle = await Vehicle.create({ userId, type: 'camper', make: 'Fiat', model: 'Ducato' });
    vehicleId = vehicle.id;
  });

  afterAll(async () => {
    await CamperSpec.destroy({ where: { vehicleId } });
    await Vehicle.destroy({ where: { id: vehicleId } });
    await User.destroy({ where: { id: userId } });
  });

  test('POST /camperSpecs - crea specifica tecnica', async () => {
    const res = await request(app)
      .post('/camperSpecs')
      .set('Authorization', token)
      .send({ vehicleId, height: 3.0, width: 2.2, length: 7.2, weight: 3.5 });
    expect(res.statusCode).toBe(201);
    expect(res.body.vehicleId).toBe(vehicleId);
    specId = res.body.id;
  });

  test('GET /camperSpecs/:vehicleId - leggi specifica tecnica', async () => {
    const res = await request(app)
      .get(`/camperSpecs/${vehicleId}`)
      .set('Authorization', token);
    expect(res.statusCode).toBe(200);
    expect(res.body.height).toBe(3.0);
  });

  test('PUT /camperSpecs/:id - modifica specifica tecnica', async () => {
    const res = await request(app)
      .put(`/camperSpecs/${specId}`)
      .set('Authorization', token)
      .send({ height: 3.2, width: 2.3 });
    expect(res.statusCode).toBe(200);
    expect(res.body.height).toBe(3.2);
    expect(res.body.width).toBe(2.3);
  });

  test('DELETE /camperSpecs/:id - cancella specifica tecnica', async () => {
    const res = await request(app)
      .delete(`/camperSpecs/${specId}`)
      .set('Authorization', token);
    expect(res.statusCode).toBe(204);
  });

  test('PUT /camperSpecs/:id - ownership: utente non proprietario', async () => {
    // Crea altro utente e token
    const otherUser = await User.create({ email: 'other@example.com', password: 'testpass' });
    const otherToken = 'Bearer ' + require('../createToken')(otherUser);
    // Ricrea specifica tecnica
    const spec = await CamperSpec.create({ vehicleId, height: 3.0, width: 2.2, length: 7.2, weight: 3.5 });
    const res = await request(app)
      .put(`/camperSpecs/${spec.id}`)
      .set('Authorization', otherToken)
      .send({ height: 4.0 });
    expect(res.statusCode).toBe(403);
    await CamperSpec.destroy({ where: { id: spec.id } });
    await User.destroy({ where: { id: otherUser.id } });
  });
});
