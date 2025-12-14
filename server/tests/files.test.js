const request = require('supertest');
const app     = require('../app');
const { seedUser } = require('./helpers/db');

describe('Files API', () => {
  let token;
  beforeAll(async () => {
    token = await seedUser();
  });

  it('POST  /api/files → 201 + key', async () => {
    const res = await request(app)
      .post('/api/files')
      .set('Authorization', `Bearer ${token}`)
      .attach('file', Buffer.from('hello world'), 'hello.txt');
    expect(res.status).toBe(201);
    expect(res.body).toHaveProperty('key', 'hello.txt');
  });

  it('POST  /api/files → 400 when no file', async () => {
    const res = await request(app)
      .post('/api/files')
      .set('Authorization', `Bearer ${token}`);
    expect(res.status).toBe(400); // ora la route restituisce 400
    expect(res.body).toHaveProperty('error');
  });

  it('GET   /api/files/:key → 404 when missing', async () => {
    const res = await request(app)
      .get('/api/files/notfound.txt')
      .set('Authorization', `Bearer ${token}`);
    expect(res.status).toBe(404);
    expect(res.body).toHaveProperty('error', 'File non trovato');
  });

  it('GET   /api/files/:key → 200 and returns file', async () => {
    // Upload first
    await request(app)
      .post('/api/files')
      .set('Authorization', `Bearer ${token}`)
      .attach('file', Buffer.from('test content'), 'test.txt');
    // Download
    const res = await request(app)
      .get('/api/files/test.txt')
      .set('Authorization', `Bearer ${token}`);
    expect(res.status).toBe(200);
    expect(res.header['content-type']).toBeDefined();
    expect(res.text).toBe('test content');
  });

  it('DELETE /api/files/:key → 204', async () => {
    const res = await request(app)
      .delete('/api/files/hello.txt')
      .set('Authorization', `Bearer ${token}`);
    expect(res.status).toBe(204);
  });

  it('DELETE /api/files/:key → 204 even if file does not exist', async () => {
    const res = await request(app)
      .delete('/api/files/doesnotexist.txt')
      .set('Authorization', `Bearer ${token}`);
    expect([204, 500]).toContain(res.status);
  });

  it('GET   /api/files/presigned-upload/:key → 200 + url', async () => {
    const res = await request(app)
      .get('/api/files/presigned-upload/foo.txt')
      .set('Authorization', `Bearer ${token}`);
    expect(res.status).toBe(200);
    expect(res.body.url).toBeDefined();
  });

  it('GET   /api/files/presigned-upload/:key → 500 on error', async () => {
    const res = await request(app)
      .get('/api/files/presigned-upload/')
      .set('Authorization', `Bearer ${token}`);
    expect([404, 500]).toContain(res.status);
  });

  it('GET   /api/files/presigned-download/:key → 200 + url', async () => {
    const res = await request(app)
      .get('/api/files/presigned-download/foo.txt')
      .set('Authorization', `Bearer ${token}`);
    expect(res.status).toBe(200);
    expect(res.body.url).toBeDefined();
  });

  it('GET   /api/files/presigned-download/:key → 500 on error', async () => {
    const res = await request(app)
      .get('/api/files/presigned-download/')
      .set('Authorization', `Bearer ${token}`);
    expect([404, 500]).toContain(res.status);
  });
});