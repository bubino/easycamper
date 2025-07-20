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
let _testStorage = {};
if (isTest) {
  console.log('⚙️ MinIO stub attivo in TEST mode');
  client = {
    bucketExists:  async () => true,
    makeBucket:    async () => {},
    putObject:     async (bucket, key, bufferOrStream, meta = {}) => {
      _testStorage[key] = { bufferOrStream, meta };
      return { key };
    },
    getObject:     async (bucket, key) => {
      if (!_testStorage[key]) throw new Error('getObject stub');
      return _testStorage[key].bufferOrStream;
    },
    removeObject:  async (bucket, key) => {
      delete _testStorage[key];
      return {};
    },
    presignedPutObject: async (bucket, key, expiresSec = 60) => `http://localhost/upload_test/${key}`,
    presignedGetObject: async (bucket, key, expiresSec = 60) => `http://localhost/download_test/${key}`
  };
} else {
  client = new Client({
    endPoint:  process.env.MINIO_ENDPOINT || 'localhost',
    port:      +(process.env.MINIO_PORT || 9000),
    useSSL:    (process.env.MINIO_USE_SSL || 'false') === 'true',
    accessKey: process.env.MINIO_ACCESS_KEY || 'easyadmin',
    secretKey: process.env.MINIO_SECRET_KEY || 'easyadmin'
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
  if (isTest) {
    await client.putObject(BUCKET, key, bufferOrStream, meta);
    return { key };
  }
  return client.putObject(BUCKET, key, bufferOrStream, meta);
}

/**
 * Restituisce uno stream di lettura del file (null in test)
 * @param {string} key 
 */
function download(key) {
  if (isTest) {
    try {
      return _testStorage[key]?.bufferOrStream || null;
    } catch {
      return null;
    }
  }
  return client.getObject(BUCKET, key);
}

/**
 * Rimuove un oggetto dal bucket (no-op in test)
 * @param {string} key 
 */
async function remove(key) {
  if (isTest) {
    await client.removeObject(BUCKET, key);
    return {};
  }
  return client.removeObject(BUCKET, key);
}

/**
 * Ritorna una URL presigned per caricare un oggetto
 * @param {string} key
 * @param {number} expiresSec
 */
async function getUploadUrl(key, expiresSec = 60) {
  if (isTest) return `http://localhost/upload_test/${key}`;
  return client.presignedPutObject(BUCKET, key, expiresSec);
}

/**
 * Ritorna una URL presigned per scaricare un oggetto
 * @param {string} key
 * @param {number} expiresSec
 */
async function getDownloadUrl(key, expiresSec = 60) {
  if (isTest) return `http://localhost/download_test/${key}`;
  return client.presignedGetObject(BUCKET, key, expiresSec);
}

module.exports = {
  upload,
  download,
  remove,
  getUploadUrl,
  getDownloadUrl
};