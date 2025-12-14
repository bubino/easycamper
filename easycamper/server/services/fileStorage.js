'use strict';

const path   = require('path');
const { Client } = require('minio');

// carica .env o .env.test in base a NODE_ENV
require('dotenv').config({
  path: path.join(
    __dirname,
    '..',
    process.env.NODE_ENV === 'test' ? '.env.test' : '.env'
  )
});

const isTest = process.env.NODE_ENV === 'test';

let client;
if (isTest) {
  console.log('⚙️ MinIO stub attivo in TEST mode');
  client = {
    bucketExists:  async () => true,
    makeBucket:    async () => {},
    putObject:     async () => {},
    getObject:     async () => { throw new Error('getObject stub'); },
    removeObject:  async () => {}
  };
} else {
  client = new Client({
    endPoint:  process.env.MINIO_ENDPOINT,
    port:      +process.env.MINIO_PORT,
    useSSL:    process.env.MINIO_USE_SSL === 'true',
    accessKey: process.env.MINIO_ACCESS_KEY,
    secretKey: process.env.MINIO_SECRET_KEY
  });
}

const BUCKET = process.env.MINIO_BUCKET;

/**
 * Assicura che il bucket esista (no-op in test)
 */
async function ensureBucket() {
  if (isTest) return;
  const exists = await client.bucketExists(BUCKET);
  if (!exists) {
    await client.makeBucket(BUCKET);
  }
}

/**
 * Carica un buffer o uno stream nel bucket
 * @param {string} key 
 * @param {Buffer|Stream} bufferOrStream 
 * @param {object} meta 
 */
async function upload(key, bufferOrStream, meta = {}) {
  await ensureBucket();
  return client.putObject(BUCKET, key, bufferOrStream, meta);
}

/**
 * Restituisce uno stream di lettura del file (null in test)
 * @param {string} key 
 */
function download(key) {
  if (isTest) return null;
  return client.getObject(BUCKET, key);
}

/**
 * Rimuove un oggetto dal bucket (no-op in test)
 * @param {string} key 
 */
async function remove(key) {
  if (isTest) return;
  return client.removeObject(BUCKET, key);
}

/**
 * Ritorna una URL presigned per caricare un oggetto
 * @param {string} key
 * @param {number} expiresSec
 */
async function getUploadUrl(key, expiresSec = 60) {
  if (isTest) return null;
  return client.presignedPutObject(BUCKET, key, expiresSec);
}

/**
 * Ritorna una URL presigned per scaricare un oggetto
 * @param {string} key
 * @param {number} expiresSec
 */
async function getDownloadUrl(key, expiresSec = 60) {
  if (isTest) return null;
  return client.presignedGetObject(BUCKET, key, expiresSec);
}

/**
 * Ritorna una URL pubblica (se il bucket è pubblico)
 * @param {string} key
 */
function getPublicUrl(key) {
  if (isTest) return `http://mock-storage/${key}`;
  const protocol = process.env.MINIO_USE_SSL === 'true' ? 'https' : 'http';
  const host = process.env.MINIO_ENDPOINT;
  const port = process.env.MINIO_PORT;
  // Gestione porta standard
  const portStr = (port === '80' || port === '443') ? '' : `:${port}`;
  return `${protocol}://${host}${portStr}/${BUCKET}/${key}`;
}

module.exports = {
  upload,
  download,
  remove,
  getUploadUrl,   // alias per getPresignedUrl in upload (PUT)
  getDownloadUrl, // alias per getPresignedUrl in download (GET)
  getPublicUrl,
  // Alias per compatibilità con routes/uploads.js se necessario
  getPresignedUrl: getUploadUrl, 
};