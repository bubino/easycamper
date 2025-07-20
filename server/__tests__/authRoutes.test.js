jest.mock('../routes/email', () => ({
  sendVerificationEmail: jest.fn().mockResolvedValue(),
  sendResetPasswordEmail: jest.fn().mockResolvedValue()
}));

const request = require('supertest');
const app = require('../app');
const { sequelize } = require('../models');
const { User } = require('../models');
const jwt = require('jsonwebtoken');

describe('Auth routes (JWT + refresh token)', () => {
  beforeEach(async () => {
    await sequelize.sync({ force: true });
  });
  afterAll(async () => {
    await sequelize.close();
  });

  test('Register and verify email', async () => {
    const res = await request(app)
      .post('/auth/register')
      .send({ username: 'testuser1', email: 'test1@example.com', password: 'Password123!' });
    expect(res.statusCode).toBe(201);
    const user = await User.findOne({ where: { email: 'test1@example.com' } });
    const verificationToken = jwt.sign({ id: user.id }, process.env.JWT_SECRET || 'testsecret', { expiresIn: '1d' });
    const verifyRes = await request(app)
      .get(`/auth/verify-email?token=${verificationToken}`);
    expect(verifyRes.statusCode).toBe(200);
    expect(verifyRes.body.message).toMatch(/Email verificata/);
  });

  test('Login after email verification', async () => {
    await request(app)
      .post('/auth/register')
      .send({ username: 'loginuser1', email: 'login1@example.com', password: 'Password123!' });
    const user = await User.findOne({ where: { email: 'login1@example.com' } });
    const verificationToken = jwt.sign({ id: user.id }, process.env.JWT_SECRET || 'testsecret', { expiresIn: '1d' });
    await request(app).get(`/auth/verify-email?token=${verificationToken}`);
    const res = await request(app)
      .post('/auth/login')
      .send({ email: 'login1@example.com', password: 'Password123!' });
    expect(res.statusCode).toBe(200);
    expect(res.body).toHaveProperty('token');
    expect(res.body).toHaveProperty('message', 'Login successful');
  });

  test('Login blocked if email not verified', async () => {
    await request(app)
      .post('/auth/register')
      .send({ username: 'unverifieduser', email: 'unverified@example.com', password: 'Password123!' });
    const res = await request(app)
      .post('/auth/login')
      .send({ email: 'unverified@example.com', password: 'Password123!' });
    expect(res.statusCode).toBe(403);
    expect(res.body.error).toMatch(/Email non verificata/);
  });

  test('Login fails with wrong password', async () => {
    await request(app)
      .post('/auth/register')
      .send({ username: 'wrongpassuser', email: 'wrongpass@example.com', password: 'Password123!' });
    const user = await User.findOne({ where: { email: 'wrongpass@example.com' } });
    const verificationToken = jwt.sign({ id: user.id }, process.env.JWT_SECRET || 'testsecret', { expiresIn: '1d' });
    await request(app).get(`/auth/verify-email?token=${verificationToken}`);
    const res = await request(app)
      .post('/auth/login')
      .send({ email: 'wrongpass@example.com', password: 'WrongPassword!' });
    expect(res.statusCode).toBe(401);
    expect(res.body).toHaveProperty('error', 'Invalid password');
  });

  test('Register', async () => {
    const res = await request(app)
      .post('/auth/register')
      .send({ username: 'testuser2', email: 'test2@example.com', password: 'Password123!' });
    expect(res.statusCode).toBe(201);
    expect(res.body).toHaveProperty('id');
    expect(res.body).toHaveProperty('email', 'test2@example.com');
    expect(res.body).toHaveProperty('username', 'testuser2');
  });

  test('Login returns JWT and refresh token cookie', async () => {
    await request(app)
      .post('/auth/register')
      .send({ username: 'loginuser2', email: 'login2@example.com', password: 'Password123!' });
    const user = await User.findOne({ where: { email: 'login2@example.com' } });
    const verificationToken = jwt.sign({ id: user.id }, process.env.JWT_SECRET || 'testsecret', { expiresIn: '1d' });
    await request(app).get(`/auth/verify-email?token=${verificationToken}`);
    const res = await request(app)
      .post('/auth/login')
      .send({ email: 'login2@example.com', password: 'Password123!' });
    expect(res.statusCode).toBe(200);
    expect(res.body).toHaveProperty('message', 'Login successful');
    expect(res.body).toHaveProperty('token');
    const cookies = res.headers['set-cookie'];
    expect(cookies.some(c => c.startsWith('refreshToken='))).toBe(true);
    const refreshTokenCookie = cookies.find(c => c.startsWith('refreshToken='));

    // Test refresh token
    const refreshRes = await request(app)
      .post('/auth/refresh')
      .set('Cookie', refreshTokenCookie);
    expect(refreshRes.statusCode).toBe(200);
    expect(refreshRes.body).toHaveProperty('token');

    // Test logout
    const logoutRes = await request(app)
      .post('/auth/logout')
      .set('Cookie', refreshTokenCookie);
    expect(logoutRes.statusCode).toBe(200);
    expect(logoutRes.text).toMatch(/Logout/);

    // Test refresh con token invalidato
    const refreshRes2 = await request(app)
      .post('/auth/refresh')
      .set('Cookie', refreshTokenCookie);
    expect(refreshRes2.statusCode).toBe(403);
  });

  test('Refresh token endpoint ruota il token e restituisce nuovo access token', async () => {
    // Prepara utente e login
    await request(app)
      .post('/auth/register')
      .send({ username: 'refreshuser', email: 'refresh@example.com', password: 'Password123!' });
    const user = await User.findOne({ where: { email: 'refresh@example.com' } });
    const verificationToken = jwt.sign({ id: user.id }, process.env.JWT_SECRET || 'testsecret', { expiresIn: '1d' });
    await request(app).get(`/auth/verify-email?token=${verificationToken}`);
    const loginRes = await request(app)
      .post('/auth/login')
      .send({ email: 'refresh@example.com', password: 'Password123!' });
    const cookies = loginRes.headers['set-cookie'];
    const refreshTokenCookie = cookies.find(c => c.startsWith('refreshToken='));

    const res = await request(app)
      .post('/auth/refresh')
      .set('Cookie', refreshTokenCookie);
    expect(res.statusCode).toBe(200);
    expect(res.body).toHaveProperty('token');
    // Il cookie refreshToken deve essere ruotato
    const cookies2 = res.headers['set-cookie'];
    expect(cookies2.some(c => c.startsWith('refreshToken='))).toBe(true);
  });

  test('Logout invalida il refresh token', async () => {
    // Prepara utente e login
    await request(app)
      .post('/auth/register')
      .send({ username: 'logoutuser', email: 'logout@example.com', password: 'Password123!' });
    const user = await User.findOne({ where: { email: 'logout@example.com' } });
    const verificationToken = jwt.sign({ id: user.id }, process.env.JWT_SECRET || 'testsecret', { expiresIn: '1d' });
    await request(app).get(`/auth/verify-email?token=${verificationToken}`);
    const loginRes = await request(app)
      .post('/auth/login')
      .send({ email: 'logout@example.com', password: 'Password123!' });
    const cookies = loginRes.headers['set-cookie'];
    const refreshTokenCookie = cookies.find(c => c.startsWith('refreshToken='));

    const res = await request(app)
      .post('/auth/logout')
      .set('Cookie', refreshTokenCookie);
    expect(res.statusCode).toBe(200);
    expect(res.text).toMatch(/Logout/);
  });

  test('Refresh con token invalidato fallisce', async () => {
    // Prepara utente e login
    await request(app)
      .post('/auth/register')
      .send({ username: 'invalidrefreshuser', email: 'invalidrefresh@example.com', password: 'Password123!' });
    const user = await User.findOne({ where: { email: 'invalidrefresh@example.com' } });
    const verificationToken = jwt.sign({ id: user.id }, process.env.JWT_SECRET || 'testsecret', { expiresIn: '1d' });
    await request(app).get(`/auth/verify-email?token=${verificationToken}`);
    const loginRes = await request(app)
      .post('/auth/login')
      .send({ email: 'invalidrefresh@example.com', password: 'Password123!' });
    const cookies = loginRes.headers['set-cookie'];
    const refreshTokenCookie = cookies.find(c => c.startsWith('refreshToken='));

    // Logout per invalidare
    await request(app)
      .post('/auth/logout')
      .set('Cookie', refreshTokenCookie);

    // Refresh deve fallire
    const res = await request(app)
      .post('/auth/refresh')
      .set('Cookie', refreshTokenCookie);
    expect(res.statusCode).toBe(403);
  });

  test('Login da due device crea due refresh token distinti', async () => {
    // Prepara utente
    await request(app)
      .post('/auth/register')
      .send({ username: 'devicetestuser', email: 'devicetest@example.com', password: 'Password123!' });
    const user = await User.findOne({ where: { email: 'devicetest@example.com' } });
    const verificationToken = jwt.sign({ id: user.id }, process.env.JWT_SECRET || 'testsecret', { expiresIn: '1d' });
    await request(app).get(`/auth/verify-email?token=${verificationToken}`);

    // Primo device
    const res1 = await request(app)
      .post('/auth/login')
      .set('User-Agent', 'DeviceA')
      .send({ email: 'devicetest@example.com', password: 'Password123!' });
    expect(res1.statusCode).toBe(200);
    const cookieA = res1.headers['set-cookie'].find(c => c.startsWith('refreshToken='));

    // Secondo device
    const res2 = await request(app)
      .post('/auth/login')
      .set('User-Agent', 'DeviceB')
      .send({ email: 'devicetest@example.com', password: 'Password123!' });
    expect(res2.statusCode).toBe(200);
    const cookieB = res2.headers['set-cookie'].find(c => c.startsWith('refreshToken='));

    expect(cookieA).not.toBe(cookieB);
  });

  test('Logout da un device non invalida l’altro', async () => {
    // Prepara utente
    await request(app)
      .post('/auth/register')
      .send({ username: 'multideviceuser', email: 'multidevice@example.com', password: 'Password123!' });
    const user = await User.findOne({ where: { email: 'multidevice@example.com' } });
    const verificationToken = jwt.sign({ id: user.id }, process.env.JWT_SECRET || 'testsecret', { expiresIn: '1d' });
    await request(app).get(`/auth/verify-email?token=${verificationToken}`);

    // Login da due device
    const resA = await request(app)
      .post('/auth/login')
      .set('User-Agent', 'DeviceA')
      .send({ email: 'multidevice@example.com', password: 'Password123!' });
    const cookieA = resA.headers['set-cookie'].find(c => c.startsWith('refreshToken='));

    const resB = await request(app)
      .post('/auth/login')
      .set('User-Agent', 'DeviceB')
      .send({ email: 'multidevice@example.com', password: 'Password123!' });
    const cookieB = resB.headers['set-cookie'].find(c => c.startsWith('refreshToken='));

    // Logout da DeviceA
    await request(app)
      .post('/auth/logout')
      .set('Cookie', cookieA);

    // Refresh da DeviceB deve funzionare
    const refreshB = await request(app)
      .post('/auth/refresh')
      .set('Cookie', cookieB);
    expect(refreshB.statusCode).toBe(200);
    expect(refreshB.body).toHaveProperty('token');

    // Refresh da DeviceA deve fallire
    const refreshA = await request(app)
      .post('/auth/refresh')
      .set('Cookie', cookieA);
    expect(refreshA.statusCode).toBe(403);
  });

  test('Verifica email: login bloccato finché non verificata', async () => {
    // Registra nuovo utente
    const res = await request(app)
      .post('/auth/register')
      .send({ username: 'mailtest', email: 'mailtest@example.com', password: 'Password123!' });
    expect(res.statusCode).toBe(201);
    // Prova login (deve fallire)
    const loginRes = await request(app)
      .post('/auth/login')
      .send({ email: 'mailtest@example.com', password: 'Password123!' });
    expect(loginRes.statusCode).toBe(403);
    expect(loginRes.body.error).toMatch(/Email non verificata/);
  });

  test('Verifica email: attivazione tramite link/token', async () => {
    // Registra nuovo utente
    await request(app)
      .post('/auth/register')
      .send({ username: 'mailtest2', email: 'mailtest2@example.com', password: 'Password123!' });
    const user = await User.findOne({ where: { email: 'mailtest2@example.com' } });
    const verificationToken = jwt.sign({ id: user.id }, process.env.JWT_SECRET || 'testsecret', { expiresIn: '1d' });
    // Verifica email
    const verifyRes = await request(app)
      .get(`/auth/verify-email?token=${verificationToken}`);
    expect(verifyRes.statusCode).toBe(200);
    expect(verifyRes.body.message).toMatch(/Email verificata/);
    // Ora login deve funzionare
    const loginRes = await request(app)
      .post('/auth/login')
      .send({ email: 'mailtest2@example.com', password: 'Password123!' });
    expect(loginRes.statusCode).toBe(200);
    expect(loginRes.body).toHaveProperty('token');
  });

  test('Reset password: richiesta e cambio', async () => {
    // Registra utente
    await request(app)
      .post('/auth/register')
      .send({ username: 'resetuser', email: 'resetuser@example.com', password: 'Password123!' });
    const user = await User.findOne({ where: { email: 'resetuser@example.com' } });
    const verificationToken = jwt.sign({ id: user.id }, process.env.JWT_SECRET || 'testsecret', { expiresIn: '1d' });
    await request(app)
      .get(`/auth/verify-email?token=${verificationToken}`);
    // Richiedi reset
    const resetReq = await request(app)
      .post('/auth/request-reset-password')
      .send({ email: 'resetuser@example.com' });
    expect(resetReq.statusCode).toBe(200);
    // Simula ricezione token
    const resetToken = jwt.sign({ id: user.id }, process.env.JWT_SECRET || 'testsecret', { expiresIn: '1h' });
    // Cambia password
    const resetRes = await request(app)
      .post('/auth/reset-password')
      .send({ token: resetToken, newPassword: 'NewPassword123!' });
    expect(resetRes.statusCode).toBe(200);
    expect(resetRes.body.message).toMatch(/Password aggiornata/);
    // Login con nuova password
    const loginRes = await request(app)
      .post('/auth/login')
      .send({ email: 'resetuser@example.com', password: 'NewPassword123!' });
    expect(loginRes.statusCode).toBe(200);
    expect(loginRes.body).toHaveProperty('token');
  });
});

test('dummy test', () => {
  expect(true).toBe(true);
});