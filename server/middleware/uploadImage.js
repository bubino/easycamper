// filepath: server/middleware/uploadImage.js
const { upload } = require('../services/fileStorage');

module.exports = async (req, _res, next) => {
  if (!req.file) return next();
  try {
    req.fileUrl = await upload(
      req.file.buffer,
      `spots/${Date.now()}_${req.file.originalname}`,
      req.file.mimetype
    );
    next();
  } catch (err) {
    next(err);
  }
};
