/* tests/files.test.js */
const request = require('supertest');
const app = require('../app');          // ← la tua express-app
const fs = require('fs');

describe('Files API', () => {
  const auth = { Authorization: 'Bearer validToken' };

  it('GET   /api/files/:key -> 401 when missing token', async () => {
    const res = await request(app).get('/api/files/notfound.txt');
    expect(res.status).toBe(401);
    expect(res.body).toHaveProperty('error');
  });

  it('POST  /api/files → 201 + key (authenticated)', async () => {
    const res = await request(app)
      .post('/api/files')
      .set(auth)
      .attach('file', Buffer.from('hello world'), 'hello.txt');

    expect(res.status).toBe(201);
    expect(res.body).toHaveProperty('key', 'hello.txt');
  });

  it('GET   /api/files/:key → 404 when missing (authenticated)', async () => {
    const res = await request(app)
      .get('/api/files/notfound.txt')
      .set(auth);

    expect(res.status).toBe(404);
    expect(res.body).toHaveProperty('error', 'File non trovato');
  });

  it('DELETE /api/files/:key → 204 (authenticated)', async () => {
    const res = await request(app)
      .delete('/api/files/hello.txt')
      .set(auth);

    expect(res.status).toBe(204);
  });

  it('GET   /api/files/presigned-upload/:key → 200 + url (authenticated)', async () => {
    const res = await request(app)
      .get('/api/files/presigned-upload/foo.txt')
      .set(auth);

    expect(res.status).toBe(200);
    expect(res.body.url).toBeDefined();
  });

  it('GET   /api/files/presigned-download/:key → 200 + url (authenticated)', async () => {
    const res = await request(app)
      .get('/api/files/presigned-download/foo.txt')
      .set(auth);

    expect(res.status).toBe(200);
    expect(res.body.url).toBeDefined();
  });

});
