// filepath: server/services/fileStorage.js
const { Client } = require('minio');

const {
  MINIO_ENDPOINT,
  MINIO_ACCESS_KEY,
  MINIO_SECRET_KEY,
  MINIO_BUCKET
} = process.env;

const [host, port] = MINIO_ENDPOINT.replace(/^https?:\/\//, '').split(':');

const minio = new Client({
  endPoint: host,
  port: +port,
  useSSL: false,
  accessKey: MINIO_ACCESS_KEY,
  secretKey: MINIO_SECRET_KEY
});

async function upload (buffer, name, mime) {
  await minio.putObject(MINIO_BUCKET, name, buffer, { 'Content-Type': mime });
  return `http://217.154.120.118:9000/${MINIO_BUCKET}/${name}`;
}
module.exports = { upload };
