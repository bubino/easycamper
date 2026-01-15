'use strict';

const request = require('supertest');
const jwt = require('jsonwebtoken');

const app = require('../app');
const db = require('../models');
const { upload } = require('../services/fileStorage');

function makeToken(userId) {
  return jwt.sign({ id: userId }, process.env.JWT_SECRET || 'testsecret');
}

describe('Avatar endpoints', () => {
  let user;
  let token;

  beforeAll(async () => {
    user = await db.User.create({
      email: 'avatar@test.com',
      username: 'avatar_user',
      password: 'Password123!'
    });
    token = makeToken(user.id);
  });

  test('POST /users/me/avatar/presigned-upload returns key and url', async () => {
    const res = await request(app)
      .post('/users/me/avatar/presigned-upload')
      .set('Authorization', `Bearer ${token}`)
      .send({});

    expect(res.statusCode).toBe(200);
    expect(typeof res.body.key).toBe('string');
    expect(res.body.key).toContain(`users/${user.id}/avatar/`);
    expect(typeof res.body.url).toBe('string');
  });

  test('POST /users/me/avatar/confirm rejects missing object', async () => {
    const key = `users/${user.id}/avatar/does-not-exist.jpg`;

    const res = await request(app)
      .post('/users/me/avatar/confirm')
      .set('Authorization', `Bearer ${token}`)
      .send({ key });

    expect(res.statusCode).toBe(400);
  });

  test('confirm + presigned-download + delete flow', async () => {
    // Simula un file caricato su storage in test tramite lo stub
    const key = `users/${user.id}/avatar/${Date.now()}.jpg`;
    await upload(key, Buffer.from('fakeimagebytes'), { 'Content-Type': 'image/jpeg' });

    const confirm = await request(app)
      .post('/users/me/avatar/confirm')
      .set('Authorization', `Bearer ${token}`)
      .send({ key });

    expect(confirm.statusCode).toBe(200);
    expect(confirm.body.avatarKey).toBe(key);

    const download = await request(app)
      .get('/users/me/avatar/presigned-download')
      .set('Authorization', `Bearer ${token}`);

    expect(download.statusCode).toBe(200);
    expect(typeof download.body.url).toBe('string');

    const del = await request(app)
      .delete('/users/me/avatar')
      .set('Authorization', `Bearer ${token}`);

    expect(del.statusCode).toBe(204);

    const downloadAfter = await request(app)
      .get('/users/me/avatar/presigned-download')
      .set('Authorization', `Bearer ${token}`);

    expect(downloadAfter.statusCode).toBe(404);
  });
});
