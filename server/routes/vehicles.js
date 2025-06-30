'use strict';
const express = require('express');
const router  = express.Router();
const { Vehicle } = require('../models');
const authenticateToken = require('../middleware/authenticateToken');

// GET /vehicles
router.get('/', authenticateToken, async (req, res) => {
  try {
    const vehicles = await Vehicle.findAll({ where: { userId: req.user.id } });
    res.json(vehicles);
  } catch (err) {
    console.error('Errore in GET /vehicles:', err);
    res.status(500).json({ error: 'Errore del server' });
  }
});

// POST /vehicles
router.post('/', authenticateToken, async (req, res) => {
  try {
    // prendo anche l'id se passato
    const { id, type, make, model } = req.body;
    const vehicle = await Vehicle.create({
      id,
      userId: req.user.id,
      type,
      make,
      model
    });
    res.status(201).json(vehicle);
  } catch (err) {
    console.error('Errore in POST /vehicles:', err);
    res.status(500).json({ error: 'Errore del server' });
  }
});

module.exports = router;
