const { RefreshToken, sequelize } = require('../models');
const request = require('supertest');
const app = require('../app');

describe('Limite massimo 2 device attivi per utente', () => {
  beforeAll(async () => {
    await sequelize.sync({ force: true });
  });

  it('should keep only the last 2 devices active for a user', async () => {
    // Crea utente e verifica email
    await request(app)
      .post('/auth/register')
      .send({ username: 'limittest', email: 'limittest@example.com', password: 'Password123!' });
    const user = await require('../models').User.findOne({ where: { email: 'limittest@example.com' } });
    const jwt = require('jsonwebtoken');
    const verificationToken = jwt.sign({ id: user.id }, process.env.JWT_SECRET || 'testsecret', { expiresIn: '1d' });
    await request(app).get(`/auth/verify-email?token=${verificationToken}`);

    // Login da 3 device diversi
    const resA = await request(app)
      .post('/auth/login')
      .set('User-Agent', 'DeviceA')
      .send({ email: 'limittest@example.com', password: 'Password123!' });
    expect(resA.statusCode).toBe(200);
    const resB = await request(app)
      .post('/auth/login')
      .set('User-Agent', 'DeviceB')
      .send({ email: 'limittest@example.com', password: 'Password123!' });
    expect(resB.statusCode).toBe(200);
    const resC = await request(app)
      .post('/auth/login')
      .set('User-Agent', 'DeviceC')
      .send({ email: 'limittest@example.com', password: 'Password123!' });
    expect(resC.statusCode).toBe(200);

    // Recupera i device attivi
    const token = resC.body.token;
    const devicesRes = await request(app)
      .get('/auth/devices')
      .set('Authorization', `Bearer ${token}`);
    expect(devicesRes.statusCode).toBe(200);
    expect(devicesRes.body.devices.length).toBe(2);
    // I device attivi devono essere DeviceB e DeviceC
    const deviceInfos = devicesRes.body.devices.map(d => d.deviceInfo);
    expect(deviceInfos).toContain('DeviceB');
    expect(deviceInfos).toContain('DeviceC');
    expect(deviceInfos).not.toContain('DeviceA');
  });
});
