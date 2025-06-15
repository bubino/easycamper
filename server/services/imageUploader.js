'use strict';

const { uploadToCloudinary } = require('./cloudinaryUploader');

async function uploadImage(file) {
  const provider = process.env.IMAGE_PROVIDER || 'cloudinary';

  if (provider === 'cloudinary') {
    // ✅ Cloudinary via multer-storage → ha file.path, non file.buffer
    if (file.buffer) {
      return await uploadToCloudinary(file); // da buffer
    } else {
      // Fallback diretto da multer-storage-cloudinary
      return {
        url: file.path,
        filename: file.filename
      };
    }
  }

  if (provider === 's3') {
    throw new Error('S3 uploader non ancora implementato');
  }

  throw new Error(`IMAGE_PROVIDER non supportato: ${provider}`);
}

module.exports = { uploadImage };
