'use strict';
const router = require('express').Router();
const { CamperSpec, Vehicle } = require('../models');
const authenticate  = require('../middleware/authenticateToken');
const { body, param, validationResult } = require('express-validator');

/* utilità di validazione */
const validate = (req, res, next) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) return res.status(400).json({ errors: errors.array() });
  next();
};

/*───────────────────────────────────────────────────────────────
  POST /camper-specs  → crea se non esiste, altrimenti aggiorna
───────────────────────────────────────────────────────────────*/
router.post(
  '/',
  authenticate,
  body('vehicleId').isUUID().withMessage('vehicleId UUID invalido'),
  body('height').isFloat({ gt: 0 }),
  body('width').isFloat({ gt: 0 }),
  body('length').isFloat({ gt: 0 }),
  body('weight').isFloat({ gt: 0 }),
  validate,
  async (req, res) => {
    try {
      const { vehicleId, height, width, length, weight } = req.body;

      // verifica che il veicolo appartenga all’utente
      const vehicle = await Vehicle.findOne({
        where: { id: vehicleId, userId: req.user.id },
      });
      if (!vehicle) return res.status(404).json({ error: 'Veicolo non trovato' });

      // controlla se la spec esiste già
      let spec = await CamperSpec.findByPk(vehicleId);
      if (spec) {
        await spec.update({ height, width, length, weight });
        return res.status(200).json(spec);          // update → 200
      }

      // altrimenti crea
      spec = await CamperSpec.create({ vehicleId, height, width, length, weight });
      return res.status(201).json(spec);            // create → 201
    } catch (err) {
      console.error('❌ Errore in POST /camper-specs:', err);
      res.status(500).json({ error: 'Errore server' });
    }
  },
);

/*───────────────────────────────────────────────────────────────
  GET /camper-specs/:vehicleId
───────────────────────────────────────────────────────────────*/
router.get(
  '/:vehicleId',
  authenticate,
  param('vehicleId').isUUID(),
  validate,
  async (req, res) => {
    try {
      const spec = await CamperSpec.findOne({
        where: { vehicleId: req.params.vehicleId },
        include: { model: Vehicle, as: 'vehicle' },
      });
      if (!spec) return res.status(404).json({ error: 'Spec non trovata' });
      res.json(spec);
    } catch (err) {
      console.error('❌ Errore in GET /camper-specs/:vehicleId:', err);
      res.status(500).json({ error: 'Errore server' });
    }
  },
);

/*───────────────────────────────────────────────────────────────
  PUT /camper-specs/:vehicleId
───────────────────────────────────────────────────────────────*/
router.put(
  '/:vehicleId',
  authenticate,
  param('vehicleId').isUUID(),
  body('height').optional().isFloat({ gt: 0 }),
  body('width').optional().isFloat({ gt: 0 }),
  body('length').optional().isFloat({ gt: 0 }),
  body('weight').optional().isFloat({ gt: 0 }),
  validate,
  async (req, res) => {
    try {
      const [rows] = await CamperSpec.update(req.body, {
        where: { vehicleId: req.params.vehicleId },
      });
      if (!rows) return res.status(404).json({ error: 'Spec non trovata' });
      const spec = await CamperSpec.findByPk(req.params.vehicleId);
      res.json(spec);
    } catch (err) {
      console.error('❌ Errore in PUT /camper-specs/:vehicleId:', err);
      res.status(500).json({ error: 'Errore server' });
    }
  },
);

/*───────────────────────────────────────────────────────────────
  DELETE /camper-specs/:vehicleId
───────────────────────────────────────────────────────────────*/
router.delete(
  '/:vehicleId',
  authenticate,
  param('vehicleId').isUUID(),
  validate,
  async (req, res) => {
    try {
      const rows = await CamperSpec.destroy({
        where: { vehicleId: req.params.vehicleId },
      });
      if (!rows) return res.status(404).json({ error: 'Spec non trovata' });
      res.sendStatus(204);
    } catch (err) {
      console.error('❌ Errore in DELETE /camper-specs/:vehicleId:', err);
      res.status(500).json({ error: 'Errore server' });
    }
  },
);

module.exports = router;