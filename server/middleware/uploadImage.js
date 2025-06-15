// middleware/uploadImage.js
const multer = require('multer');
const { CloudinaryStorage } = require('multer-storage-cloudinary');
const { cloudinary } = require('../services/cloudinaryUploader');

const storage = new CloudinaryStorage({
  cloudinary,
  params: {
    folder: 'easycamper',
    allowed_formats: ['jpg', 'jpeg', 'png', 'webp', 'heic', 'mp4', 'mov'],
    resource_type: 'auto' // 💡 auto rileva se è immagine o video
  },
});

const upload = multer({ storage });

// Esporta entrambi per flessibilità: singolo o multiplo
module.exports = {
  uploadSingle: upload.single('image'),
  uploadMultiple: upload.array('images', 5), // fino a 5 immagini per esempio
};
