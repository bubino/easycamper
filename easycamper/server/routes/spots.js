'use strict';
const router   = require('express').Router();
const { Spot, SpotImage } = require('../models');

// GET /spots
router.get('/', async (req, res) => {
  const spots = await Spot.findAll({ where: { userId: req.user.id } });
  res.json(spots);
});

// POST /spots
router.post('/', async (req, res) => {
  try {
    const { photos, ...spotData } = req.body;
    const spot = await Spot.create({ ...spotData, userId: req.user.id });

    if (photos && Array.isArray(photos) && photos.length > 0) {
      const imageRecords = photos.map(url => ({
        spotId: spot.id,
        userId: req.user.id,
        url: url
      }));
      await SpotImage.bulkCreate(imageRecords);
    }

    // Ricarichiamo lo spot con le immagini per restituirlo completo
    const fullSpot = await Spot.findByPk(spot.id, {
      include: [{ model: SpotImage, as: 'images' }]
    });

    // Formattiamo la risposta per includere 'photos' come array di stringhe
    const spotJson = fullSpot.toJSON();
    spotJson.photos = spotJson.images ? spotJson.images.map(img => img.url) : [];
    delete spotJson.images;

    res.status(201).json(spotJson);
  } catch (error) {
    console.error('Errore creazione spot:', error);
    res.status(500).json({ error: 'Errore durante la creazione dello spot' });
  }
});

// GET /spots/:id
router.get('/:id', async (req, res) => {
  const spot = await Spot.findOne({
    where: { id: req.params.id, userId: req.user.id },
    include: [{ model: SpotImage, as: 'images' }]
  });
  if (!spot) return res.status(404).json({ error: 'Spot non trovato' });
  
  // Formattiamo la risposta per includere un array semplice di URL 'photos'
  const spotJson = spot.toJSON();
  spotJson.photos = spotJson.images ? spotJson.images.map(img => img.url) : [];
  delete spotJson.images; // pulizia opzionale

  res.json({ spot: spotJson });
});

// PUT /spots/:id
router.put('/:id', async (req, res) => {
  const [rows] = await Spot.update(req.body, {
    where: { id: req.params.id, userId: req.user.id },
  });
  if (!rows) return res.status(404).json({ error: 'Spot non trovato' });
  const spot = await Spot.findByPk(req.params.id);
  res.json(spot);
});

// DELETE /spots/:id
router.delete('/:id', async (req, res) => {
  const rows = await Spot.destroy({
    where: { id: req.params.id, userId: req.user.id },
  });
  if (!rows) return res.status(404).json({ error: 'Spot non trovato' });
  res.status(204).end();
});

module.exports = router;