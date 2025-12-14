'use strict';
const express = require('express');
const router = express.Router();
const { FavoriteSpot, Spot } = require('../models');
const authenticateToken = require('../middleware/authenticateToken');
const { body, param, validationResult } = require('express-validator');

/**
 * @swagger
 * tags:
 *   name: Favorites
 *   description: Gestione degli spot preferiti dagli utenti
 */

/**
 * @swagger
 * /favorites:
 *   get:
 *     summary: Ottiene tutti gli spot preferiti dell'utente autenticato
 *     tags: [Favorites]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: Lista degli spot preferiti
 */
router.get('/', authenticateToken, async (req, res) => {
  try {
    const favorites = await FavoriteSpot.findAll({
      where: { userId: req.user.id },
      include: {
        model: Spot,
        as: 'spot'
      }
    });
    res.json(favorites);
  } catch (err) {
    console.error('❌ Errore in GET /favorites:', err);
    res.status(500).json({ error: 'Errore nel recupero dei preferiti' });
  }
});

/**
 * @swagger
 * /favorites:
 *   post:
 *     summary: Aggiunge uno spot ai preferiti dell'utente
 *     tags: [Favorites]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - spotId
 *             properties:
 *               spotId:
 *                 type: string
 *     responses:
 *       201:
 *         description: Preferito aggiunto con successo
 *       400:
 *         description: Errore di validazione o già esistente
 */
router.post(
  '/',
  authenticateToken,
  body('spotId').isUUID().withMessage('spotId deve essere un UUID valido'),
  async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ errors: errors.array() });
    }

    try {
      const { spotId } = req.body;
      // Controlla se già esiste
      const existing = await FavoriteSpot.findOne({
        where: { userId: req.user.id, spotId }
      });
      if (existing) {
        return res.status(400).json({ error: 'Spot già nei preferiti' });
      }

      const favorite = await FavoriteSpot.create({
        id: require('crypto').randomUUID(),
        userId: req.user.id,
        spotId
      });

      res.status(201).json(favorite);
    } catch (err) {
      console.error('❌ Errore in POST /favorites:', err);
      res.status(500).json({ error: 'Errore nell\'aggiunta ai preferiti' });
    }
  }
);

/**
 * @swagger
 * /favorites/{id}:
 *   delete:
 *     summary: Rimuove uno spot dai preferiti dell'utente
 *     tags: [Favorites]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *           format: uuid
 *     responses:
 *       200:
 *         description: Preferito rimosso con successo
 *       404:
 *         description: Preferito non trovato
 */
router.delete('/:id',
  authenticateToken,
  param('id').isUUID().withMessage('ID preferito non valido'),
  async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ errors: errors.array() });
    }

    try {
      const deleted = await FavoriteSpot.destroy({
        where: { id: req.params.id, userId: req.user.id }
      });
      if (!deleted) {
        return res.status(404).json({ error: 'Preferito non trovato' });
      }
      res.json({ message: 'Preferito rimosso con successo' });
    } catch (err) {
      console.error('❌ Errore in DELETE /favorites/:id:', err);
      res.status(500).json({ error: 'Errore nella rimozione dai preferiti' });
    }
  }
);

module.exports = router;
