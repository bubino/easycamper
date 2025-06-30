const request = require('supertest');
const app     = require('../app');  // se sei già in /server, usa '../app'

describe('Files API', () => {
  it('POST  /api/files → 201 + key', async () => {
    const res = await request(app)
      .post('/api/files')
      .attach('file', Buffer.from('hello world'), 'hello.txt');
    expect(res.status).toBe(201);
    expect(res.body).toHaveProperty('key', 'hello.txt');
  });

  it('GET   /api/files/:key → 404 when missing', async () => {
    const res = await request(app).get('/api/files/notfound.txt');
    expect(res.status).toBe(404);
    expect(res.body).toHaveProperty('error', 'File non trovato');
  });

  it('DELETE /api/files/:key → 204', async () => {
    const res = await request(app).delete('/api/files/hello.txt');
    expect(res.status).toBe(204);
  });

  it('GET   /api/files/presigned-upload/:key → 200 + url', async () => {
    const res = await request(app).get('/api/files/presigned-upload/foo.txt');
    expect(res.status).toBe(200);
    expect(res.body.url).toBeDefined();
  });

  it('GET   /api/files/presigned-download/:key → 200 + url', async () => {
    const res = await request(app).get('/api/files/presigned-download/foo.txt');
    expect(res.status).toBe(200);
    expect(res.body.url).toBeDefined();
  });
});