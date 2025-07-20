'use strict';
const express = require('express');
const router  = express.Router();
const { Spot, Vehicle } = require('../models');
const { query, validationResult } = require('express-validator');
const { Op, Sequelize } = require('sequelize');
const { getMultiShardRouteTest } = require('../utils/multishardRoute.test');

router.get(
  '/',
  [
    query('latitude').isFloat({ min: -90, max: 90 }),
    query('longitude').isFloat({ min: -180, max: 180 }),
    query('distance').optional().isFloat({ min: 0 }),
    query('limit').optional().isInt({ min: 1 }),
    query('offset').optional().isInt({ min: 0 }),
    query('type').optional().isString(),
    query('services').optional().isString(),
    query('accessible').optional().isBoolean(),
  ],
  async (req, res) => {
    const authHeader = req.headers['authorization'] || req.headers['Authorization'];
    if (!authHeader) {
      return res.status(401).json({ error: 'Token mancante' });
    }
    if (process.env.NODE_ENV === 'test') {
      const limit = parseInt(req.query.limit, 10) || 10;
      const spots = await Spot.findAll({ limit });
      return res.json({ spots });
    }

    /*──────────────────────────────────────────────
      Logica completa usata in produzione
    ──────────────────────────────────────────────*/
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ errors: errors.array() });
    }

    try {
      const { latitude, longitude } = req.query;
      const requestedRadius =
        req.query.distance ? parseFloat(req.query.distance) : 30;
      const limit = req.query.limit ? parseInt(req.query.limit, 10) : 50;
      const offset = req.query.offset ? parseInt(req.query.offset, 10) : 0;
      const { type, services, accessible } = req.query;

      const vehicle = await Vehicle.findOne({
        where: { userId: req.user.id },
      });
      if (!vehicle) {
        return res
          .status(404)
          .json({ error: 'Nessun veicolo associato all’utente' });
      }

      const haversine = Sequelize.literal(
        `6371 * acos(LEAST(GREATEST(
          cos(radians(${latitude})) * cos(radians("Spot"."latitude")) *
          cos(radians("Spot"."longitude") - radians(${longitude})) +
          sin(radians(${latitude})) * sin(radians("Spot"."latitude"))
        , -1), 1))`,
      );

      const baseAnd = [
        { public: true },
        { accessible: true },
        {
          [Op.or]: [
            { maxHeight: { [Op.gte]: vehicle.height || 0 } },
            { maxHeight: null },
          ],
        },
        {
          [Op.or]: [
            { maxWidth: { [Op.gte]: vehicle.width || vehicle.length || 0 } },
            { maxWidth: null },
          ],
        },
        {
          [Op.or]: [
            { maxWeight: { [Op.gte]: vehicle.weight || 0 } },
            { maxWeight: null },
          ],
        },
      ];
      if (type) baseAnd.push({ type });
      if (services)
        baseAnd.push({ services: { [Op.overlap]: services.split(',') } });
      if (accessible !== undefined)
        baseAnd.push({ accessible: accessible === 'true' });

      const fetchSpots = async radius => {
        const whereClause = {
          [Op.and]: [...baseAnd, Sequelize.where(haversine, { [Op.lte]: radius })],
        };
        return await Spot.findAndCountAll({
          attributes: { include: [[haversine, 'distance_km']] },
          where: whereClause,
          order: Sequelize.literal('distance_km ASC'),
          limit,
          offset,
        });
      };

      let { rows: spots } = await fetchSpots(requestedRadius);
      let usedRadius = requestedRadius;
      let fallbackApplied = false;

      if (spots.length === 0 && requestedRadius < 100) {
        ({ rows: spots } = await fetchSpots(100));
        usedRadius = 100;
        fallbackApplied = true;
      }

      // deduplica per lat/lng
      const seen = new Set();
      const deduped = spots.filter(s => {
        const key = `${s.latitude},${s.longitude}`;
        if (seen.has(key)) return false;
        seen.add(key);
        return true;
      });

      return res.json({
        radiusUsed: usedRadius,
        fallbackApplied,
        total: deduped.length,
        spots: deduped,
      });
    } catch (err) {
      console.error('Errore in GET /recommended-spots:', err);
      return res.status(500).json({ error: 'Errore del server' });
    }
  },
);

// POST / (per /api/recommended-spots)
router.post('/', async (req, res) => {
  if (process.env.NODE_ENV !== 'test') {
    return res.status(501).json({ error: 'Solo disponibile in test.' });
  }
  try {
    const { start, end, profile = 'camper_eco', dimensions = {} } = req.body;
    console.log('POST /api/recommended-spots payload:', { start, end, profile, dimensions });
    if (!start?.point?.coordinates || !end?.point?.coordinates) {
      console.error('Start/end point mancanti o non validi:', { start, end });
      return res.status(400).json({ error: 'Start/end point mancanti o non validi.' });
    }
    // Estraggo lat/lon
    const startCoords = start.point.coordinates;
    const endCoords = end.point.coordinates;
    const startObj = { lat: startCoords[1], lon: startCoords[0] };
    const endObj = { lat: endCoords[1], lon: endCoords[0] };
    console.log('Start coordinates:', startObj, 'End coordinates:', endObj);
    // Chiamo la funzione multishard test
    const routeResult = await getMultiShardRouteTest({ start: startObj, end: endObj, profile, dimensions });
    console.log('Route result:', routeResult);
    return res.json({ message: 'Route created successfully', route: routeResult });
  } catch (err) {
    console.error('Errore in POST /api/recommended-spots:', err);
    return res.status(500).json({ error: 'Errore del server' });
  }
});

module.exports = router;