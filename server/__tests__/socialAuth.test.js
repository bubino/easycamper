// Mock social providers PRIMA di importare app.js
jest.mock('google-auth-library', () => ({
  OAuth2Client: jest.fn().mockImplementation(() => ({
    verifyIdToken: jest.fn().mockResolvedValue({
      getPayload: () => ({
        email: 'googleuser@example.com'
      })
    })
  }))
}));

jest.mock('apple-signin-auth', () => ({
  verifyIdToken: jest.fn().mockResolvedValue({
    email: 'appleuser@example.com'
  })
}));

global.fetch = jest.fn().mockResolvedValue({
  json: async () => ({
    email: 'fbuser@example.com',
    name: 'FB User'
  })
});

const request = require('supertest');
const app = require('../app');

describe('Social login', () => {
  beforeAll(() => {
    jest.spyOn(console, 'log').mockImplementation(() => {});
  });
  afterAll(() => {
    jest.restoreAllMocks();
  });

  test('Login con Google: utente nuovo', async () => {
    const res = await request(app)
      .post('/auth/google')
      .send({ idToken: 'fake-google-token' });
    expect(res.statusCode).toBe(200);
    expect(res.body).toHaveProperty('token');
    expect(res.body).toHaveProperty('userId');
    expect(res.body.message).toMatch(/Google/);
  });

  test('Login con Facebook: utente nuovo', async () => {
    const res = await request(app)
      .post('/auth/facebook')
      .send({ accessToken: 'fake-fb-token', userID: '123' });
    expect(res.statusCode).toBe(200);
    expect(res.body).toHaveProperty('token');
    expect(res.body).toHaveProperty('userId');
    expect(res.body.message).toMatch(/Facebook/);
  });

  test('Login con Apple: utente nuovo', async () => {
    const res = await request(app)
      .post('/auth/apple')
      .send({ idToken: 'fake-apple-token' });
    expect(res.statusCode).toBe(200);
    expect(res.body).toHaveProperty('token');
    expect(res.body).toHaveProperty('userId');
    expect(res.body.message).toMatch(/Apple/);
  });
});

describe('Social login - errori e casi limite', () => {
  afterEach(() => {
    jest.resetAllMocks();
  });

  test('Google: token non valido', async () => {
    const { OAuth2Client } = require('google-auth-library');
    OAuth2Client.mockImplementation(() => ({
      verifyIdToken: jest.fn().mockRejectedValue(new Error('Invalid token'))
    }));
    const res = await request(app)
      .post('/auth/google')
      .send({ idToken: 'invalid-token' });
    expect(res.statusCode).toBe(401);
    expect(res.body.error).toMatch(/token/i);
  });

  test('Apple: token scaduto', async () => {
    const appleSignin = require('apple-signin-auth');
    appleSignin.verifyIdToken.mockRejectedValue(new Error('Token expired'));
    const res = await request(app)
      .post('/auth/apple')
      .send({ idToken: 'expired-token' });
    expect(res.statusCode).toBe(401);
    expect(res.body.error).toMatch(/token/i);
  });

  test('Facebook: provider non raggiungibile', async () => {
    global.fetch.mockImplementationOnce(() => {
      const err = new Error('Network error');
      err.code = 'ENOTFOUND';
      throw err;
    });
    const res = await request(app)
      .post('/auth/facebook')
      .send({ accessToken: 'any', userID: 'any' });
    expect(res.statusCode).toBe(502);
    expect(res.body.error).toMatch(/facebook/i);
  });

  test('Facebook: risposta malformata', async () => {
    global.fetch.mockImplementationOnce(() => ({
      ok: true,
      status: 200,
      json: async () => { throw new Error('malformed'); }
    }));
    const res = await request(app)
      .post('/auth/facebook')
      .send({ accessToken: 'any', userID: 'any' });
    expect(res.statusCode).toBe(400);
    expect(res.body.error).toMatch(/facebook/i);
  });

  test('Registrazione con social diversi ma stessa email', async () => {
    // Primo login con Google
    const resGoogle = await request(app)
      .post('/auth/google')
      .send({ idToken: 'fake-google-token' });
    expect(resGoogle.statusCode).toBe(200);
    // Ora mock Facebook per restituire la stessa email
    global.fetch.mockResolvedValue({ json: async () => ({ email: 'googleuser@example.com', name: 'FB User' }) });
    const resFacebook = await request(app)
      .post('/auth/facebook')
      .send({ accessToken: 'any', userID: 'any' });
    expect(resFacebook.statusCode).toBe(200);
    expect(resFacebook.body.userId).toBe(resGoogle.body.userId);
  });
});

describe('Social login - robustezza e edge case', () => {
  test('Race condition: login social simultanei con stessa email', async () => {
    // Mock Google e Facebook per restituire la stessa email
    const { OAuth2Client } = require('google-auth-library');
    OAuth2Client.mockImplementation(() => ({
      verifyIdToken: jest.fn().mockResolvedValue({
        getPayload: () => ({ email: 'race@example.com' })
      })
    }));
    global.fetch.mockImplementationOnce(() => ({
      ok: true,
      status: 200,
      json: async () => ({ email: 'race@example.com', name: 'FB User' })
    }));
    // Esegui login Google e Facebook quasi in parallelo
    const [resGoogle, resFacebook] = await Promise.all([
      request(app).post('/auth/google').send({ idToken: 'race-token' }),
      request(app).post('/auth/facebook').send({ accessToken: 'any', userID: 'any' })
    ]);
    expect(resGoogle.statusCode).toBe(200);
    expect(resFacebook.statusCode).toBe(200);
    // Devono avere lo stesso userId
    expect(resGoogle.body.userId).toBe(resFacebook.body.userId);
  });

  test('Edge case: login social con email mancante', async () => {
    // Mock Google senza email
    const { OAuth2Client } = require('google-auth-library');
    OAuth2Client.mockImplementation(() => ({
      verifyIdToken: jest.fn().mockResolvedValue({
        getPayload: () => ({})
      })
    }));
    const res = await request(app)
      .post('/auth/google')
      .send({ idToken: 'no-email-token' });
    expect(res.statusCode).toBe(400);
    expect(res.body.error).toMatch(/email/i);
  });

  test('Edge case: login social con nome mancante', async () => {
    // Mock Facebook senza nome
    global.fetch.mockResolvedValue({ json: async () => ({ email: 'noname@example.com' }) });
    const res = await request(app)
      .post('/auth/facebook')
      .send({ accessToken: 'any', userID: 'any' });
    expect(res.statusCode).toBe(200);
    expect(res.body).toHaveProperty('userId');
    // Username fallback: parte locale dell'email
    expect(res.body).toHaveProperty('token');
  });

  test('Login social su utente già registrato con email/password', async () => {
    // Crea utente classico
    const userRes = await request(app)
      .post('/auth/register')
      .send({ email: 'classic@example.com', password: 'Test1234!', username: 'ClassicUser' });
    expect(userRes.statusCode).toBe(201);
    // Ora login social con stessa email (Google)
    const { OAuth2Client } = require('google-auth-library');
    OAuth2Client.mockImplementation(() => ({
      verifyIdToken: jest.fn().mockResolvedValue({
        getPayload: () => ({ email: 'classic@example.com' })
      })
    }));
    const res = await request(app)
      .post('/auth/google')
      .send({ idToken: 'classic-token' });
    expect(res.statusCode).toBe(200);
    expect(res.body.userId).toBeDefined();
  });
});
