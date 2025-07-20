const { RefreshToken, sequelize } = require('../models');
const request = require('supertest');
const app = require('../app');
const jwt = require('jsonwebtoken');

describe('Sicurezza refresh token', () => {
  beforeAll(async () => {
    await sequelize.sync({ force: true });
    // Crea utente e verifica email
    await request(app)
      .post('/auth/register')
      .send({ username: 'securitytest', email: 'securitytest@example.com', password: 'Password123!' });
    const user = await require('../models').User.findOne({ where: { email: 'securitytest@example.com' } });
    const verificationToken = jwt.sign({ id: user.id }, process.env.JWT_SECRET || 'testsecret', { expiresIn: '1d' });
    await request(app).get(`/auth/verify-email?token=${verificationToken}`);
  });

  it('should reject refresh with expired token', async () => {
    const user = await require('../models').User.findOne({ where: { email: 'securitytest@example.com' } });
    const expiredRefreshToken = jwt.sign({ id: user.id }, process.env.REFRESH_TOKEN_SECRET || 'refreshsecret', { expiresIn: '-1s' });
    const res = await request(app)
      .post('/auth/refresh')
      .set('Cookie', [`refreshToken=${expiredRefreshToken}`]);
    expect(res.statusCode).toBe(403);
  });

  it('should reject refresh with tampered token', async () => {
    const user = await require('../models').User.findOne({ where: { email: 'securitytest@example.com' } });
    const validRefreshToken = jwt.sign({ id: user.id }, process.env.REFRESH_TOKEN_SECRET || 'refreshsecret', { expiresIn: '7d' });
    // Manomissione: cambia una lettera
    const tampered = validRefreshToken.slice(0, -1) + 'X';
    const res = await request(app)
      .post('/auth/refresh')
      .set('Cookie', [`refreshToken=${tampered}`]);
    expect(res.statusCode).toBe(403);
  });

  it('should reject refresh from unauthorized device', async () => {
    const user = await require('../models').User.findOne({ where: { email: 'securitytest@example.com' } });
    // Crea un refresh token valido ma non registrato in tabella
    const fakeRefreshToken = jwt.sign({ id: user.id }, process.env.REFRESH_TOKEN_SECRET || 'refreshsecret', { expiresIn: '7d' });
    const res = await request(app)
      .post('/auth/refresh')
      .set('Cookie', [`refreshToken=${fakeRefreshToken}`]);
    expect(res.statusCode).toBe(403);
  });
});
