const request = require('supertest');
const app = require('../app');
const { sequelize, User } = require('../models');

jest.mock('../routes/email', () => ({
  sendVerificationEmail: jest.fn().mockResolvedValue(),
  sendResetPasswordEmail: jest.fn().mockResolvedValue()
}));

describe('User registration (test)', () => {
  beforeAll(async () => {
    await sequelize.sync({ force: true });
  });

  it('should register a new user', async () => {
    const res = await request(app)
      .post('/auth/register')
      .send({
        username: 'testuser',
        email: 'test@example.com',
        password: 'testpass'
      });
    expect(res.statusCode).toBe(201);
    // Verifica email
    const user = await User.findOne({ where: { email: 'test@example.com' } });
    const verificationToken = require('jsonwebtoken').sign({ id: user.id }, process.env.JWT_SECRET || 'testsecret', { expiresIn: '1d' });
    const verifyRes = await request(app)
      .get(`/auth/verify-email?token=${verificationToken}`);
    expect(verifyRes.statusCode).toBe(200);
    expect(verifyRes.body.message).toMatch(/Email verificata/);
  });

  it('should login a registered user', async () => {
    await request(app)
      .post('/auth/register')
      .send({
        username: 'loginuser',
        email: 'login@example.com',
        password: 'loginpass'
      });
    // Verifica email
    const user = await User.findOne({ where: { email: 'login@example.com' } });
    const verificationToken = require('jsonwebtoken').sign({ id: user.id }, process.env.JWT_SECRET || 'testsecret', { expiresIn: '1d' });
    await request(app).get(`/auth/verify-email?token=${verificationToken}`);
    const res = await request(app)
      .post('/auth/login')
      .send({
        email: 'login@example.com',
        password: 'loginpass'
      });
    expect(res.statusCode).toBe(200);
    expect(res.body).toHaveProperty('message', 'Login successful');
    expect(res.body).toHaveProperty('token');
  });

  it('should fail to login with wrong password', async () => {
    await request(app)
      .post('/auth/register')
      .send({
        username: 'wrongpassuser',
        email: 'wrongpass@example.com',
        password: 'rightpass'
      });
    // Verifica email
    const user = await User.findOne({ where: { email: 'wrongpass@example.com' } });
    const verificationToken = require('jsonwebtoken').sign({ id: user.id }, process.env.JWT_SECRET || 'testsecret', { expiresIn: '1d' });
    await request(app).get(`/auth/verify-email?token=${verificationToken}`);
    const res = await request(app)
      .post('/auth/login')
      .send({
        email: 'wrongpass@example.com',
        password: 'wrongpassword'
      });
    expect(res.statusCode).toBe(401);
    expect(res.body).toHaveProperty('error', 'Invalid password');
  });

  it('should update user profile name', async () => {
    await request(app)
      .post('/auth/register')
      .send({
        username: 'profileuser',
        email: 'profile@example.com',
        password: 'profilepass'
      });
    // Verifica email
    const user = await User.findOne({ where: { email: 'profile@example.com' } });
    const verificationToken = require('jsonwebtoken').sign({ id: user.id }, process.env.JWT_SECRET || 'testsecret', { expiresIn: '1d' });
    await request(app).get(`/auth/verify-email?token=${verificationToken}`);
    const res = await request(app)
      .put('/auth/profile')
      .send({
        email: 'profile@example.com',
        name: 'NuovoNome'
      });
    expect(res.statusCode).toBe(200);
    expect(res.body).toHaveProperty('message', 'Profile updated');
    expect(res.body).toHaveProperty('name', 'NuovoNome');
  });
});