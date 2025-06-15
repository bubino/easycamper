'use strict';
const router   = require('express').Router();
const { Spot } = require('../models');

// GET /spots
router.get('/', async (req, res) => {
  const spots = await Spot.findAll({ where: { userId: req.user.id } });
  res.json(spots);
});

// POST /spots
router.post('/', async (req, res) => {
  const spot = await Spot.create({ ...req.body, userId: req.user.id });
  res.status(201).json(spot);
});

// GET /spots/:id
router.get('/:id', async (req, res) => {
  const spot = await Spot.findOne({
    where: { id: req.params.id, userId: req.user.id },
  });
  if (!spot) return res.status(404).json({ error: 'Spot non trovato' });
  res.json(spot);
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