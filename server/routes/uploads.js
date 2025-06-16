'use strict';

const router    = require('express').Router();
const multer    = require('multer');
const uploadMem = multer({ storage: multer.memoryStorage() });

const authenticate = require('../middleware/authenticateToken'); // togli se vuoi endpoint pubblico
const uploadImage  = require('../middleware/uploadImage');

// POST /api/uploads  – field name: image
router.post(
  '/',
  //authenticate,                 // commenta per test senza JWT
  uploadMem.single('image'),
  uploadImage,
  (req, res) => res.json({ url: req.fileUrl })
);

module.exports = router;