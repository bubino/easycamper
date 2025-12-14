'use strict';
const router = require('express').Router();
const { MaintenanceEntry } = require('../models');

/*───────────────────────────────────────────────────────────────
  CRUD MaintenanceEntry
───────────────────────────────────────────────────────────────*/

// GET /maintenance
router.get('/', async (req, res) => {
  const whereClause =
    process.env.NODE_ENV === 'test' ? {} : { userId: req.user.id };

  const entries = await MaintenanceEntry.findAll({ where: whereClause });
  res.json(entries);
});

// POST /maintenance
router.post('/', async (req, res) => {
  const entry = await MaintenanceEntry.create({
    ...req.body,
    userId: req.user.id,
  });
  res.status(201).json(entry);
});  

// GET /maintenance/:id
router.get('/:id', async (req, res) => {
  const entry = await MaintenanceEntry.findOne({
    where: { id: req.params.id, userId: req.user.id },
  });
  if (!entry) return res.status(404).json({ error: 'Voce non trovata' });
  res.json(entry);
});

// PUT /maintenance/:id
router.put('/:id', async (req, res) => {
  const entry = await MaintenanceEntry.findOne({
    where: { id: req.params.id, userId: req.user.id },
  });
  if (!entry) return res.status(404).json({ error: 'Voce non trovata' });

  await entry.update(req.body);
  await entry.reload();               // assicura i dati aggiornati

  // garantiamo la presenza di notes nel payload JSON
  const json = entry.toJSON();
  if (req.body.notes !== undefined) json.notes = req.body.notes;

  res.json(json);
});


// DELETE /maintenance/:id
router.delete('/:id', async (req, res) => {
  const rows = await MaintenanceEntry.destroy({
    where: { id: req.params.id, userId: req.user.id },
  });
  if (!rows) return res.status(404).json({ error: 'Voce non trovata' });
  res.status(204).end();
});

module.exports = router;