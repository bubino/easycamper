'use strict';
const router = require('express').Router();
const { Op } = require('sequelize');
const { Spot } = require('../models');

// GET /spots - lista per mappa con bbox + filtri
router.get('/', async (req, res, next) => {
  try {
    const { bbox, types, services, minRating, page = 1, limit = 50 } = req.query;

    if (!bbox) {
      return res.status(400).json({ error: 'Parametro bbox obbligatorio' });
    }

    const [latMin, lngMin, latMax, lngMax] = bbox.split(',').map(Number);
    const pageNum = Number(page) || 1;
    const limitNum = Math.min(Number(limit) || 50, 200);
    const offset = (pageNum - 1) * limitNum;

    const where = {
      latitude: { [Op.between]: [latMin, latMax] },
      longitude: { [Op.between]: [lngMin, lngMax] },
    };

    if (types) {
      const typeList = Array.isArray(types) ? types : [types];
      where.type = { [Op.in]: typeList };
    }

    if (minRating) {
      where.ratingAverage = { [Op.gte]: Number(minRating) };
    }

    if (services) {
      const servicesList = Array.isArray(services) ? services : [services];
      // filtro semplice: tutti i servizi richiesti devono essere true nel JSON services
      servicesList.forEach((svc) => {
        where[`services.${svc}`] = true;
      });
    }

    const { rows, count } = await Spot.findAndCountAll({
      where,
      limit: limitNum,
      offset,
      order: [['ratingAverage', 'DESC']],
      attributes: [
        'id',
        'name',
        'shortDescription',
        'latitude',
        'longitude',
        'type',
        'ratingAverage',
        'ratingCount',
        'services',
        'tags',
      ],
    });

    res.json({
      page: pageNum,
      limit: limitNum,
      total: count,
      spots: rows,
    });
  } catch (err) {
    next(err);
  }
});

// GET /spots/:id - dettaglio
router.get('/:id', async (req, res, next) => {
  try {
    const id = String(req.params.id || '').trim();
    // UUID v4/v1 generic check
    const uuidRe = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
    if (!uuidRe.test(id)) {
      // Avoid DB errors like "invalid input syntax for type uuid"
      return res.status(400).json({ error: 'ID spot non valido' });
    }

    const spot = await Spot.findByPk(id);
    if (!spot) {
      return res.status(404).json({ error: 'Spot non trovato' });
    }
    res.json(spot);
  } catch (err) {
    next(err);
  }
});

// POST /spots - crea un nuovo spot
router.post('/', async (req, res, next) => {
  try {
    const { name, description, latitude, longitude, type, services } = req.body || {};

    if (!name || latitude == null || longitude == null) {
      return res.status(400).json({ error: 'name, latitude e longitude sono obbligatori' });
    }

    // userId impostato dal middleware authenticate in app.js
    const userId = req.user && req.user.id;
    if (!userId) {
      return res.status(401).json({ error: 'Utente non autenticato' });
    }

    const spot = await Spot.create({
      userId,
      name,
      description,
      latitude,
      longitude,
      type,
      services,
    });

    return res.status(201).json(spot);
  } catch (err) {
    return next(err);
  }
});

module.exports = router;