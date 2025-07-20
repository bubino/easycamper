const request = require('supertest');
const app = require('../app');
const { sequelize, User } = require('../models');

jest.mock('../routes/email', () => ({
  sendVerificationEmail: jest.fn().mockResolvedValue(),
  sendResetPasswordEmail: jest.fn().mockResolvedValue()
}));

describe('User registration, login, and profile (PRODUZIONE)', () => {
  beforeAll(async () => {
    await sequelize.sync({ force: true });
  });

  it('should register a new user (prod)', async () => {
    const res = await request(app)
      .post('/auth/register')
      .send({
        username: 'produser',
        email: 'prod@example.com',
        password: 'prodpass'
      });
    expect(res.statusCode).toBe(201);
    // Verifica email
    const user = await User.findOne({ where: { email: 'prod@example.com' } });
    const verificationToken = require('jsonwebtoken').sign({ id: user.id }, process.env.JWT_SECRET || 'testsecret', { expiresIn: '1d' });
    const verifyRes = await request(app)
      .get(`/auth/verify-email?token=${verificationToken}`);
    expect(verifyRes.statusCode).toBe(200);
    expect(verifyRes.body.message).toMatch(/Email verificata/);
  });

  it('should login a registered user (prod)', async () => {
    await request(app)
      .post('/auth/register')
      .send({
        username: 'prodlogin',
        email: 'prodlogin@example.com',
        password: 'prodloginpass'
      });
    // Verifica email
    const user = await User.findOne({ where: { email: 'prodlogin@example.com' } });
    const verificationToken = require('jsonwebtoken').sign({ id: user.id }, process.env.JWT_SECRET || 'testsecret', { expiresIn: '1d' });
    await request(app).get(`/auth/verify-email?token=${verificationToken}`);
    // Ora testa il login
    const res = await request(app)
      .post('/auth/login')
      .send({
        email: 'prodlogin@example.com',
        password: 'prodloginpass'
      });
    expect(res.statusCode).toBe(200);
    expect(res.body).toHaveProperty('message', 'Login successful');
  });

  it('should update user profile name (prod)', async () => {
    await request(app)
      .post('/auth/register')
      .send({
        username: 'prodprofile',
        email: 'prodprofile@example.com',
        password: 'prodprofilepass'
      });
    // Verifica email
    const user = await User.findOne({ where: { email: 'prodprofile@example.com' } });
    const verificationToken = require('jsonwebtoken').sign({ id: user.id }, process.env.JWT_SECRET || 'testsecret', { expiresIn: '1d' });
    await request(app).get(`/auth/verify-email?token=${verificationToken}`);
    // Modifica il nome
    const res = await request(app)
      .put('/auth/profile')
      .send({
        email: 'prodprofile@example.com',
        name: 'NuovoNomeProd'
      });
    expect(res.statusCode).toBe(200);
    expect(res.body).toHaveProperty('message', 'Profile updated');
    expect(res.body).toHaveProperty('name', 'NuovoNomeProd');
  });
});