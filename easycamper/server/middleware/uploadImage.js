// filepath: server/middleware/uploadImage.js
const { upload, getPublicUrl } = require('../services/fileStorage');

module.exports = async (req, _res, next) => {
  if (!req.file) return next();
  try {
    const key = `spots/${Date.now()}_${req.file.originalname}`;
    // Fix: upload(key, buffer, meta) - ordine argomenti corretto
    await upload(
      key,
      req.file.buffer,
      { 'Content-Type': req.file.mimetype }
    );
    
    // Imposta l'URL pubblico
    req.fileUrl = getPublicUrl(key);
    
    next();
  } catch (err) {
    next(err);
  }
};
