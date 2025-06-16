// filepath: server/routes/uploads.js
const router    = require('express').Router();
const multer    = require('multer');
const uploadMem = multer({ storage: multer.memoryStorage() });

const authenticate = require('../middleware/authenticateToken'); // togli se pubblico
const uploadImage  = require('../middleware/uploadImage');

router.post(
  '/',
  authenticate,               // commenta se non serve auth
  uploadMem.single('image'),
  uploadImage,
  (req, res) => res.json({ url: req.fileUrl })
);

module.exports = router;
