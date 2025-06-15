'use strict';
const express = require('express');
const router = express.Router();
const { upload } = require('../services/cloudinaryUploader');
const { uploadImage } = require('../services/imageUploader');

/**
 * @swagger
 * /upload:
 *   post:
 *     summary: Carica un'immagine su Cloudinary
 *     tags: [Upload]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         multipart/form-data:
 *           schema:
 *             type: object
 *             properties:
 *               image:
 *                 type: string
 *                 format: binary
 *     responses:
 *       200:
 *         description: URL dell'immagine caricata
 */
router.post('/', upload.single('image'), async (req, res) => {
  try {
    if (!req.file) return res.status(400).json({ error: 'Nessun file caricato' });

    const result = await uploadImage(req.file);
    res.status(200).json({ url: result.url, filename: result.filename });
  } catch (err) {
    console.error('❌ Errore in POST /upload:', err);
    res.status(500).json({ error: 'Errore nel caricamento immagine' });
  }
});

module.exports = router;
