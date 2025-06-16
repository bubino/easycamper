'use strict';

const express    = require('express');
const multer     = require('multer');
const uploadMem  = multer({ storage: multer.memoryStorage() });
const authenticate = require('../middleware/authenticateToken');
const uploadImage  = require('../middleware/uploadImage');

const router = express.Router();

// se vuoi rendere pubblico commenta la riga seguente
router.use(authenticate);

// POST /api/uploads     – field name: image
router.post(
  '/',
  uploadMem.single('image'),
  uploadImage,
  (req, res) => res.json({ url: req.fileUrl })
);

module.exports = router;