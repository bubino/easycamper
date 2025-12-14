'use strict';
const express = require('express');
const router  = express.Router();
const { Vehicle, VehicleModel } = require('../models');
const authenticateToken = require('../middleware/authenticateToken');
const { body, param } = require('express-validator');

// GET /vehicles
router.get('/', authenticateToken, async (req, res) => {
  try {
    const { limit = 20, offset = 0, type, make, model, year } = req.query;
    const where = { userId: req.user.id };
    if (type) where.type = type;
    if (make) where.make = make;
    if (model) where.model = model;
    if (year) where.year = parseInt(year);
    const vehicles = await Vehicle.findAll({
      where,
      limit: parseInt(limit),
      offset: parseInt(offset)
    });
    res.json(vehicles);
  } catch (err) {
    console.error('Errore in GET /vehicles:', err);
    res.status(500).json({ error: 'Errore del server' });
  }
});

// POST /vehicles
router.post('/',
  authenticateToken,
  body('id').optional().isUUID().withMessage('id deve essere UUID'),
  body('type').isString().isLength({ min: 2, max: 20 }).isIn(['camper', 'van', 'autocaravan']).withMessage('Tipo veicolo non valido'),
  body('make').isString().isLength({ min: 2, max: 30 }).withMessage('Marca troppo corta/lunga'),
  body('model').isString().isLength({ min: 1, max: 30 }).withMessage('Modello troppo corto/lungo'),
  body('year').optional().isInt({ min: 2010, max: 2025 }).withMessage('Anno non valido'),
  body('vehicleModelId').optional().isString().withMessage('vehicleModelId deve essere stringa'),
  async (req, res) => {
    const errors = require('express-validator').validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ errors: errors.array() });
    }
    try {
      const { id, type, make, model, year, vehicleModelId } = req.body;

      let length = req.body.length;
      let height = req.body.height;
      let weight = req.body.weight;

      let resolvedVehicleModelId = vehicleModelId || null;

      if (vehicleModelId) {
        const vm = await VehicleModel.findByPk(vehicleModelId);
        if (!vm) {
          return res.status(400).json({ error: 'vehicleModelId non valido' });
        }
        // Se i campi tecnici non sono specificati, ereditali dal modello
        if (length == null && vm.length_m != null) length = vm.length_m;
        if (height == null && vm.height_m != null) height = vm.height_m;
        if (weight == null && vm.weight_kg != null) weight = vm.weight_kg;
      }

      const vehicle = await Vehicle.create({
        id,
        userId: req.user.id,
        type,
        make,
        model,
        year,
        length,
        height,
        weight,
        vehicleModelId: resolvedVehicleModelId,
      });
      res.status(201).json(vehicle);
    } catch (err) {
      console.error('Errore in POST /vehicles:', err);
      res.status(500).json({ error: 'Errore del server' });
    }
  }
);

// PUT /vehicles/:id
router.put('/:id',
  authenticateToken,
  param('id').isUUID(),
  body('type').optional().isString().isLength({ min: 2, max: 20 }).isIn(['camper', 'van', 'autocaravan']).withMessage('Tipo veicolo non valido'),
  body('make').optional().isString().isLength({ min: 2, max: 30 }).withMessage('Marca troppo corta/lunga'),
  body('model').optional().isString().isLength({ min: 1, max: 30 }).withMessage('Modello troppo corto/lungo'),
  body('year').optional().isInt({ min: 2010, max: 2025 }).withMessage('Anno non valido'),
  body('vehicleModelId').optional().isString().withMessage('vehicleModelId deve essere stringa'),
  async (req, res) => {
    const errors = require('express-validator').validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ errors: errors.array() });
    }
    try {
      const vehicle = await Vehicle.findOne({
        where: { id: req.params.id, userId: req.user.id }
      });
      if (!vehicle) {
        console.warn(`[SECURITY] Tentativo PUT non autorizzato: userId=${req.user.id}, vehicleId=${req.params.id}`);
        return res.status(404).json({ error: 'Veicolo non trovato' });
      }

      const updates = {};
      const { type, make, model, year, vehicleModelId } = req.body;
      if (type !== undefined) updates.type = type;
      if (make !== undefined) updates.make = make;
      if (model !== undefined) updates.model = model;
      if (year !== undefined) updates.year = year;

      let length = req.body.length;
      let height = req.body.height;
      let weight = req.body.weight;

      if (vehicleModelId !== undefined) {
        if (vehicleModelId === null) {
          updates.vehicleModelId = null;
        } else {
          const vm = await VehicleModel.findByPk(vehicleModelId);
          if (!vm) {
            return res.status(400).json({ error: 'vehicleModelId non valido' });
          }
          updates.vehicleModelId = vehicleModelId;
          // Se i campi tecnici non sono specificati nell'update, possiamo opzionalmente aggiornare dai valori del modello
          if (length == null && vm.length_m != null) length = vm.length_m;
          if (height == null && vm.height_m != null) height = vm.height_m;
          if (weight == null && vm.weight_kg != null) weight = vm.weight_kg;
        }
      }

      if (length !== undefined) updates.length = length;
      if (height !== undefined) updates.height = height;
      if (weight !== undefined) updates.weight = weight;

      await vehicle.update(updates);
      res.json(vehicle);
    } catch (err) {
      console.error('Errore in PUT /vehicles/:id:', err);
      res.status(500).json({ error: 'Errore del server' });
    }
  }
);

// DELETE /vehicles/:id
router.delete('/:id', authenticateToken, async (req, res) => {
  try {
    const rows = await Vehicle.destroy({
      where: { id: req.params.id, userId: req.user.id }
    });
    if (!rows) {
      console.warn(`[SECURITY] Tentativo DELETE non autorizzato: userId=${req.user.id}, vehicleId=${req.params.id}`);
      return res.status(404).json({ error: 'Veicolo non trovato' });
    }
    res.sendStatus(204);
  } catch (err) {
    console.error('Errore in DELETE /vehicles/:id:', err);
    res.status(500).json({ error: 'Errore del server' });
  }
});

module.exports = router;
