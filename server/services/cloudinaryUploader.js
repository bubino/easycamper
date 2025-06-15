'use strict';
const cloudinary = require('cloudinary').v2;
const streamifier = require('streamifier');
const { CloudinaryStorage } = require('multer-storage-cloudinary');
const multer = require('multer');

cloudinary.config({
  cloud_name: process.env.CLOUDINARY_CLOUD_NAME,
  api_key:    process.env.CLOUDINARY_API_KEY,
  api_secret: process.env.CLOUDINARY_API_SECRET
});

const storage = new CloudinaryStorage({
  cloudinary,
  params: {
    folder: 'easycamper',
    allowed_formats: ['jpg', 'jpeg', 'png']
  },
});

const upload = multer({ storage });

/**
 * Upload diretto da buffer a Cloudinary (fallback o uso alternativo)
 */
function uploadToCloudinary(file) {
  return new Promise((resolve, reject) => {
    const stream = cloudinary.uploader.upload_stream(
      {
        folder: 'easycamper',
        resource_type: 'image'
      },
      (error, result) => {
        if (error) reject(error);
        else resolve(result);
      }
    );
    streamifier.createReadStream(file.buffer).pipe(stream);
  });
}

module.exports = {
  cloudinary,
  upload,
  uploadToCloudinary
};
