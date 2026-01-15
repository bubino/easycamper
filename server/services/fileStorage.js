'use strict';

const path = require('path');
const { Client } = require('minio');
const { Readable } = require('stream');

// carica .env in base a NODE_ENV (allineato a server/app.js)
const envFile =
  process.env.NODE_ENV === 'test'
    ? '.env.test'
    : process.env.NODE_ENV === 'development'
      ? '.env.development'
      : '.env';

require('dotenv').config({
  path: path.join(__dirname, '..', envFile),
});

const isTest = process.env.NODE_ENV === 'test';

// Backward-compatible env (MINIO_*) and new generic S3_* (recommended for R2)
const ENDPOINT =
  process.env.S3_ENDPOINT || process.env.MINIO_ENDPOINT || 'localhost';
const PORT = Number(process.env.S3_PORT || process.env.MINIO_PORT || 9000);
const USE_SSL =
  String(process.env.S3_USE_SSL || process.env.MINIO_USE_SSL || 'false') ===
  'true';
const ACCESS_KEY =
  process.env.S3_ACCESS_KEY || process.env.MINIO_ACCESS_KEY || 'easyadmin';
const SECRET_KEY =
  process.env.S3_SECRET_KEY || process.env.MINIO_SECRET_KEY || 'easyadmin';

// Fail fast in non-test environments if credentials are missing/placeholder.
if (!isTest) {
  const bad = (v) =>
    !v ||
    v === 'easyadmin' ||
    v.startsWith('CHANGE_ME__') ||
    v.includes('YOUR_') ||
    v.includes('REPLACE_ME');

  if (bad(ACCESS_KEY) || bad(SECRET_KEY)) {
    throw new Error(
      'Storage credentials missing/placeholder. Set S3_ACCESS_KEY and S3_SECRET_KEY (Cloudflare R2) as container env vars (recommended) or in server/.env (not recommended).'
    );
  }
}

// For R2 set this to the bucket name (e.g. easycamper)
const BUCKET =
  process.env.S3_BUCKET || process.env.MINIO_BUCKET || 'easycamper';

// Public base URL for objects (optional). Example:
// https://<accountid>.r2.cloudflarestorage.com/<bucket>
const PUBLIC_BASE_URL =
  process.env.S3_PUBLIC_BASE_URL || process.env.MINIO_PUBLIC_BASE_URL || '';

// Default public base URL (best effort) if S3_PUBLIC_BASE_URL is not set.
// NOTE: For Cloudflare R2 the r2.cloudflarestorage.com endpoint is the S3 API
// endpoint and might NOT serve objects publicly. Prefer configuring
// S3_PUBLIC_BASE_URL to a real public domain (r2.dev / custom domain / worker).
const DEFAULT_PUBLIC_BASE_URL =
  process.env.S3_ENDPOINT && BUCKET
    ? `https://${process.env.S3_ENDPOINT.replace(/^https?:\/\//, '')}/${BUCKET}`
    : '';

let client;
let _testStorage = {};

if (isTest) {
  console.log('⚙️ Storage stub attivo in TEST mode');
  client = {
    bucketExists: async () => true,
    makeBucket: async () => {},
    putObject: async (_bucket, key, bufferOrStream, meta = {}) => {
      _testStorage[key] = { bufferOrStream, meta };
      return { key };
    },
    getObject: async (_bucket, key) => {
      if (!_testStorage[key]) throw new Error('getObject stub');
      return _testStorage[key].bufferOrStream;
    },
    removeObject: async (_bucket, key) => {
      delete _testStorage[key];
      return {};
    },
    presignedPutObject: async (_bucket, key, _expiresSec = 60) =>
      `http://localhost/upload_test/${key}`,
    presignedGetObject: async (_bucket, key, _expiresSec = 60) =>
      `http://localhost/download_test/${key}`,
  };
} else {
  client = new Client({
    endPoint: ENDPOINT,
    port: PORT,
    useSSL: USE_SSL,
    accessKey: ACCESS_KEY,
    secretKey: SECRET_KEY,
    // Region is not required by minio client for S3-compatible endpoints.
  });
}

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
    return { key, url: getPublicUrl(key) };
  }
  await client.putObject(BUCKET, key, bufferOrStream, meta);
  return { key, url: getPublicUrl(key) };
}

/**
 * Restituisce uno stream di lettura del file (null in test)
 * @param {string} key
 */
function download(key) {
  if (isTest) {
    try {
      const buf = _testStorage[key]?.bufferOrStream || null;
      if (!buf) return null;
      return Readable.from(buf);
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

/**
 * Ritorna la URL pubblica di un oggetto (se configurata)
 * @param {string} key
 */
function getPublicUrl(key) {
  const baseUrl = (PUBLIC_BASE_URL || DEFAULT_PUBLIC_BASE_URL || '').trim();
  if (!baseUrl) return '';

  const base = baseUrl.endsWith('/') ? baseUrl.slice(0, -1) : baseUrl;
  const safeKey = String(key || '').replace(/^\/+/, '');

  // Avoid duplicating bucket path if the configured base already ends with /<bucket>
  // and key is also prefixed with <bucket>/...
  const bucketPrefix = `${BUCKET}/`;
  if (safeKey.startsWith(bucketPrefix) && base.endsWith(`/${BUCKET}`)) {
    return `${base}/${safeKey.slice(bucketPrefix.length)}`;
  }

  return `${base}/${safeKey}`;
}

module.exports = {
  upload,
  download,
  remove,
  getUploadUrl,
  getDownloadUrl,
  getPublicUrl,
};