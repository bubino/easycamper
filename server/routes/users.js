// server/routes/users.js
const express = require('express');
const router  = express.Router();
const { User } = require('../models');

// POST /users
router.post('/', async (req, res, next) => {
  try {
    const user = await User.create(req.body);
    res.status(201).json(user);
  } catch (err) {
    next(err);
  }
});

// GET /users
router.get('/', async (_req, res, next) => {
  try {
    const users = await User.findAll();
    res.json(users);
  } catch (err) {
    next(err);
  }
});

// GET /users/:id
router.get('/:id', async (req, res, next) => {
  try {
    const user = await User.findByPk(req.params.id);
    if (!user) return res.status(404).json({ error: 'Not found' });
    res.json(user);
  } catch (err) {
    next(err);
  }
});

// PUT /users/:id
router.put('/:id', async (req, res, next) => {
  try {
    const [n] = await User.update(req.body, { where: { id: req.params.id } });
    if (!n) return res.status(404).json({ error: 'Not found' });
    const updated = await User.findByPk(req.params.id);
    res.json(updated);
  } catch (err) {
    next(err);
  }
});

// DELETE /users/:id
router.delete('/:id', async (req, res, next) => {
  try {
    const n = await User.destroy({ where: { id: req.params.id } });
    if (!n) return res.status(404).json({ error: 'Not found' });
    res.status(204).end();
  } catch (err) {
    next(err);
  }
});

module.exports = router;
