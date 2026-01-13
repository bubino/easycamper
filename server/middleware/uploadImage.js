// filepath: server/middleware/uploadImage.js
const { upload } = require('../services/fileStorage');

module.exports = async (req, _res, next) => {
  if (!req.file) return next();
  try {
    const key = `spots/${Date.now()}_${req.file.originalname}`;
    const result = await upload(key, req.file.buffer, {
      'Content-Type': req.file.mimetype,
    });
    // Prefer the public URL if available, otherwise return the key.
    req.fileUrl = result.url || result.key;
    next();
  } catch (err) {
    next(err);
  }
};
