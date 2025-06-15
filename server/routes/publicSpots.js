'use strict';
const express = require('express');
const router = express.Router();
const { Spot } = require('../models');
const { Op, Sequelize } = require('sequelize');

/**
 * @swagger
 * tags:
 *   name: PublicSpots
 *   description: Esplora gli spot pubblici visibili a tutti
 */

/**
 * @swagger
 * /public-spots:
 *   get:
 *     summary: Ottiene tutti gli spot pubblici con filtri avanzati
 *     tags: [PublicSpots]
 *     parameters:
 *       - in: query
 *         name: name
 *         schema:
 *           type: string
 *       - in: query
 *         name: description
 *         schema:
 *           type: string
 *       - in: query
 *         name: latitude
 *         schema:
 *           type: number
 *       - in: query
 *         name: longitude
 *         schema:
 *           type: number
 *       - in: query
 *         name: distance
 *         schema:
 *           type: number
 *       - in: query
 *         name: type
 *         schema:
 *           type: string
 *       - in: query
 *         name: services
 *         schema:
 *           type: string
 *       - in: query
 *         name: features
 *         schema:
 *           type: string
 *       - in: query
 *         name: accessible
 *         schema:
 *           type: boolean
 *     responses:
 *       200:
 *         description: Lista degli spot pubblici trovati
 */
router.get('/', async (req, res) => {
  try {
    const {
      name, description, latitude, longitude, distance,
      type, services, features, accessible
    } = req.query;

    const filters = {
      public: true,
      ...(name && { name }),
      ...(description && { description }),
      ...(type && { type })
    };

    const serviceFilter = services ? { services: { [Op.overlap]: services.split(',') } } : {};
    const featureFilter = features ? { features: { [Op.overlap]: features.split(',') } } : {};
    const accessibleFilter = accessible !== undefined
      ? { accessible: accessible === 'true' }
      : {};

    let haversineFormula = null;
    let distanceKm = null;

    if (latitude && longitude && distance) {
      distanceKm = parseFloat(distance);
      haversineFormula = Sequelize.literal(`
        6371 * acos(LEAST(GREATEST(
          cos(radians(${latitude}))
          * cos(radians("Spot"."latitude"))
          * cos(radians("Spot"."longitude") - radians(${longitude}))
          + sin(radians(${latitude})) * sin(radians("Spot"."latitude")),
        -1), 1))
      `);
    }

    const queryOptions = {
      where: {
        ...filters,
        ...serviceFilter,
        ...featureFilter,
        ...accessibleFilter
      }
    };

    if (haversineFormula) {
      queryOptions.attributes = {
        include: [[haversineFormula, 'distance_km']]
      };
      queryOptions.where = {
        [Op.and]: [
          queryOptions.where,
          Sequelize.where(haversineFormula, { [Op.lte]: distanceKm })
        ]
      };
      queryOptions.order = Sequelize.literal(`distance_km ASC`);
    }

    const spots = await Spot.findAll(queryOptions);
    res.json(spots);
  } catch (err) {
    console.error('❌ Errore in GET /public-spots:', err);
    res.status(500).json({ error: 'Errore del server' });
  }
});

module.exports = router;
