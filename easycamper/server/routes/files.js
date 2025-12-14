'use strict';
const express             = require('express');
const multer              = require('multer');
const {
  upload,
  download,
  remove,
  getUploadUrl,
  getDownloadUrl
} = require('../services/fileStorage');

const router        = express.Router();
const uploadSingle  = multer().single('file');

// POST   /api/files
router.post('/files', uploadSingle, async (req, res) => {
  try {
    const { originalname, buffer, mimetype } = req.file;
    await upload(originalname, buffer, { 'Content-Type': mimetype });
    res.status(201).json({ key: originalname });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Upload fallito' });
  }
});

// GET    /api/files/:key
router.get('/files/:key', async (req, res) => {
  try {
    const stream = await download(req.params.key);
    if (!stream) return res.status(404).json({ error: 'File non trovato' });
    stream.pipe(res);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Download fallito' });
  }
});

// DELETE /api/files/:key
router.delete('/files/:key', async (req, res) => {
  try {
    await remove(req.params.key);
    res.status(204).end();
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Delete fallito' });
  }
});

// GET    /api/files/presigned-upload/:key
router.get('/files/presigned-upload/:key', async (req, res) => {
  try {
    const url = await getUploadUrl(req.params.key, 300);
    res.json({ url });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Errore presigned-upload' });
  }
});

// GET    /api/files/presigned-download/:key
router.get('/files/presigned-download/:key', async (req, res) => {
  try {
    const url = await getDownloadUrl(req.params.key, 300);
    res.json({ url });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Errore presigned-download' });
  }
});

module.exports = router;