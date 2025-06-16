'use strict';

const express    = require('express');
const multer     = require('multer');
const uploadMem  = multer({ storage: multer.memoryStorage() });
const authenticate = require('../middleware/authenticateToken');
const { getPresignedUrl, getPublicUrl } = require('../services/fileStorage');

const router = express.Router();
router.use(authenticate); // commenta se vuoi pubblica

// 1) GET  /api/uploads/spots/:id/photo-url
router.get('/spots/:id/photo-url', async (req, res, next) => {
  try {
    const key = `spots/${req.params.id}/${Date.now()}.jpg`;
    const url = await getPresignedUrl(key);
    res.json({ key, url });
  } catch (err) {
    next(err);
  }
});

// 2) POST /api/uploads/spots/:id/photo
//     body: { "key":"spots/123/...jpg" }
router.post('/spots/:id/photo', async (req, res, next) => {
  try {
    const { key } = req.body;
    const url = getPublicUrl(key);
    // TODO: salva url in DB se serve
    res.status(201).json({ url });
  } catch (err) {
    next(err);
  }
});

module.exports = router;