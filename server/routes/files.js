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
router.post('/', uploadSingle, async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ error: 'File mancante' });
    }
    const { originalname, buffer, mimetype } = req.file;
    await upload(originalname, buffer, { 'Content-Type': mimetype });
    res.status(201).json({ key: originalname });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Upload fallito' });
  }
});

// GET    /api/files/presigned-upload/:key
router.get('/presigned-upload/:key', async (req, res) => {
  try {
    const url = await getUploadUrl(req.params.key, 300);
    res.json({ url });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Errore presigned-upload' });
  }
});

// GET    /api/files/presigned-download/:key
router.get('/presigned-download/:key', async (req, res) => {
  try {
    const url = await getDownloadUrl(req.params.key, 300);
    res.json({ url });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Errore presigned-download' });
  }
});

// GET    /api/files/:key
router.get('/:key', async (req, res) => {
  try {
    const stream = await download(req.params.key);
    if (!stream) return res.status(404).json({ error: 'File non trovato' });
    if (typeof stream.pipe !== 'function') {
      return res.status(500).json({ error: 'Download fallito (stream non valido)' });
    }
    // Imposta content-type se txt
    if (req.params.key.endsWith('.txt')) {
      res.type('text/plain');
    } else {
      res.type('application/octet-stream');
    }
    stream.pipe(res);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Download fallito' });
  }
});

// DELETE /api/files/:key
router.delete('/:key', async (req, res) => {
  try {
    await remove(req.params.key);
    res.status(204).end();
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Delete fallito' });
  }
});

module.exports = router;