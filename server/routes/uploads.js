'use strict';

const express = require('express');
const multer = require('multer');
const uploadMem = multer({ storage: multer.memoryStorage() });
const authenticate = require('../middleware/authenticateToken');
const uploadImage = require('../middleware/uploadImage');
const {
  getUploadUrl,
  getPublicUrl,
} = require('../services/fileStorage');

const router = express.Router();

// Se vuoi accesso pubblico commenta la riga seguente
router.use(authenticate);

// 0) POST  /api/uploads           ← multipart/form-data
router.post(
  '/',
  uploadMem.single('image'),
  uploadImage,
  (req, res) => res.json({ url: req.fileUrl })
);

// 1) GET   /api/uploads/spots/:id/photo-url   ← presigned URL
router.get('/spots/:id/photo-url', async (req, res, next) => {
  try {
    const key = `spots/${req.params.id}/${Date.now()}.jpg`;
    const url = await getUploadUrl(key, 300);
    res.json({ key, url });
  } catch (err) {
    next(err);
  }
});

// 1b) GET  /api/uploads/spots/:spotId/reviews/photo-url → presigned URL
router.get('/spots/:spotId/reviews/photo-url', async (req, res, next) => {
  try {
    const key = `spots/${req.params.spotId}/reviews/${Date.now()}.jpg`;
    const url = await getUploadUrl(key, 300);
    res.json({ key, url });
  } catch (err) {
    next(err);
  }
});

// 2) POST  /api/uploads/spots/:id/photo       ← public URL
router.post('/spots/:id/photo', async (req, res, next) => {
  try {
    const { key } = req.body;
    const url = getPublicUrl(key);
    res.status(201).json({ key, url });
  } catch (err) {
    next(err);
  }
});

// 2b) POST /api/uploads/spots/:spotId/reviews/photo → public URL
router.post('/spots/:spotId/reviews/photo', async (req, res, next) => {
  try {
    const { key } = req.body;
    const url = getPublicUrl(key);
    res.status(201).json({ key, url });
  } catch (err) {
    next(err);
  }
});

module.exports = router;