'use strict';
const router = require('express').Router();
const { Op } = require('sequelize');
const { Spot, SpotReview, User, sequelize } = require('../models');

function isValidUuid(id) {
  const uuidRe = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
  return uuidRe.test(String(id || '').trim());
}

async function recomputeSpotRating(spotId, transaction) {
  const rows = await SpotReview.findAll({
    where: { spotId },
    attributes: ['rating'],
    transaction,
  });

  const ratings = rows.map(r => Number(r.rating)).filter(n => Number.isFinite(n));
  const count = ratings.length;
  const avg = count === 0 ? null : ratings.reduce((a, b) => a + b, 0) / count;

  await Spot.update(
    {
      ratingAverage: avg,
      ratingCount: count,
    },
    { where: { id: spotId }, transaction },
  );
}

function safeString(v) {
  return typeof v === 'string' ? v.trim() : '';
}

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
        'userId',
        'name',
        'shortDescription',
        'latitude',
        'longitude',
        'type',
        'ratingAverage',
        'ratingCount',
        'services',
        'tags',
        'photos',
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
    if (!isValidUuid(id)) {
      // Avoid DB errors like "invalid input syntax for type uuid"
      return res.status(400).json({ error: 'ID spot non valido' });
    }

    const spot = await Spot.findByPk(id, {
      attributes: {
        exclude: ['updatedAt'],
      },
    });

    if (!spot) {
      return res.status(404).json({ error: 'Spot non trovato' });
    }
    res.json(spot);
  } catch (err) {
    next(err);
  }
});

// POST /spots/:id/photos - collega URL foto allo spot (solo owner)
router.post('/:id/photos', async (req, res, next) => {
  try {
    const id = String(req.params.id || '').trim();
    if (!isValidUuid(id)) {
      return res.status(400).json({ error: 'ID spot non valido' });
    }

    const userId = req.user && req.user.id;
    if (!userId) {
      return res.status(401).json({ error: 'Utente non autenticato' });
    }

    const spot = await Spot.findOne({ where: { id, userId } });
    if (!spot) {
      return res.status(404).json({ error: 'Spot non trovato' });
    }

    const body = req.body || {};
    const urls = [];

    if (typeof body.url === 'string' && body.url.trim().length > 0) {
      urls.push(body.url.trim());
    }
    if (Array.isArray(body.urls)) {
      for (const u of body.urls) {
        if (typeof u === 'string' && u.trim().length > 0) {
          urls.push(u.trim());
        }
      }
    }

    if (urls.length === 0) {
      return res.status(400).json({ error: 'Nessuna url fornita' });
    }

    const existing = Array.isArray(spot.photos) ? spot.photos : [];
    const merged = [...existing];
    for (const u of urls) {
      if (!merged.includes(u)) merged.push(u);
    }

    await spot.update({ photos: merged });
    return res.status(201).json({ photos: spot.photos });
  } catch (err) {
    return next(err);
  }
});

// POST /spots - crea un nuovo spot
router.post('/', async (req, res, next) => {
  try {
    const { name, description, latitude, longitude, type, services, rating } = req.body || {};

    if (!name || latitude == null || longitude == null) {
      return res.status(400).json({ error: 'name, latitude e longitude sono obbligatori' });
    }

    let parsedRating = null;
    if (rating != null) {
      const r = Number(rating);
      if (!Number.isFinite(r) || r < 1 || r > 5) {
        return res.status(400).json({ error: 'rating deve essere un numero tra 1 e 5' });
      }
      parsedRating = r;
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
      ...(parsedRating != null
        ? { ratingAverage: parsedRating, ratingCount: 1 }
        : {}),
    });

    return res.status(201).json(spot);
  } catch (err) {
    return next(err);
  }
});

// PUT /spots/:id - aggiorna spot (solo owner)
router.put('/:id', async (req, res, next) => {
  try {
    const id = String(req.params.id || '').trim();
    if (!isValidUuid(id)) {
      return res.status(400).json({ error: 'ID spot non valido' });
    }

    const userId = req.user && req.user.id;
    if (!userId) {
      return res.status(401).json({ error: 'Utente non autenticato' });
    }

    const spot = await Spot.findOne({ where: { id, userId } });
    if (!spot) {
      return res.status(404).json({ error: 'Spot non trovato' });
    }

    const allowed = ['name', 'description', 'shortDescription', 'latitude', 'longitude', 'type', 'services', 'tags', 'openingHours', 'priceInfo'];
    const updates = {};
    for (const key of allowed) {
      if (Object.prototype.hasOwnProperty.call(req.body || {}, key)) {
        updates[key] = req.body[key];
      }
    }

    await spot.update(updates);
    return res.json(spot);
  } catch (err) {
    return next(err);
  }
});

// DELETE /spots/:id - elimina spot (solo owner)
router.delete('/:id', async (req, res, next) => {
  try {
    const id = String(req.params.id || '').trim();
    if (!isValidUuid(id)) {
      return res.status(400).json({ error: 'ID spot non valido' });
    }

    const userId = req.user && req.user.id;
    if (!userId) {
      return res.status(401).json({ error: 'Utente non autenticato' });
    }

    const deleted = await Spot.destroy({ where: { id, userId } });
    if (!deleted) {
      return res.status(404).json({ error: 'Spot non trovato' });
    }

    return res.sendStatus(204);
  } catch (err) {
    return next(err);
  }
});

// GET /spots/:id/reviews - lista recensioni spot
router.get('/:id/reviews', async (req, res, next) => {
  try {
    const id = String(req.params.id || '').trim();
    if (!isValidUuid(id)) {
      return res.status(400).json({ error: 'ID spot non valido' });
    }

    const exists = await Spot.findByPk(id, { attributes: ['id'] });
    if (!exists) {
      return res.status(404).json({ error: 'Spot non trovato' });
    }

    const reviews = await SpotReview.findAll({
      where: { spotId: id },
      order: [['createdAt', 'DESC']],
      include: [{
        // autore (non includiamo dati sensibili)
        model: User,
        as: 'user',
        attributes: ['id', 'username', 'email'],
      }],
    });

    return res.json({ reviews });
  } catch (err) {
    return next(err);
  }
});

// POST /spots/:id/reviews - crea/aggiorna recensione dell'utente per lo spot
router.post('/:id/reviews', async (req, res, next) => {
  const t = await sequelize.transaction();
  try {
    const spotId = String(req.params.id || '').trim();
    if (!isValidUuid(spotId)) {
      await t.rollback();
      return res.status(400).json({ error: 'ID spot non valido' });
    }

    const userId = req.user && req.user.id;
    if (!userId) {
      await t.rollback();
      return res.status(401).json({ error: 'Utente non autenticato' });
    }

    const spot = await Spot.findByPk(spotId, { transaction: t, lock: t.LOCK.UPDATE });
    if (!spot) {
      await t.rollback();
      return res.status(404).json({ error: 'Spot non trovato' });
    }

    const rating = Number(req.body?.rating);
    if (!Number.isFinite(rating) || rating < 1 || rating > 5) {
      await t.rollback();
      return res.status(400).json({ error: 'rating deve essere un numero tra 1 e 5' });
    }

    const comment = safeString(req.body?.comment);

    // upsert: l'utente può avere massimo 1 review per spot (vincolo unique)
    const [review, created] = await SpotReview.findOrCreate({
      where: { spotId, userId },
      defaults: { rating, comment: comment || null },
      transaction: t,
    });

    if (!created) {
      await review.update({ rating, comment: comment || null }, { transaction: t });
    }

    await recomputeSpotRating(spotId, t);
    await t.commit();

    return res.status(created ? 201 : 200).json({ review });
  } catch (err) {
    try { await t.rollback(); } catch (_) {}
    return next(err);
  }
});

// DELETE /spots/:id/reviews/:reviewId - elimina recensione (solo autore)
router.delete('/:id/reviews/:reviewId', async (req, res, next) => {
  const t = await sequelize.transaction();
  try {
    const spotId = String(req.params.id || '').trim();
    const reviewId = String(req.params.reviewId || '').trim();
    if (!isValidUuid(spotId) || !isValidUuid(reviewId)) {
      await t.rollback();
      return res.status(400).json({ error: 'ID non valido' });
    }

    const userId = req.user && req.user.id;
    if (!userId) {
      await t.rollback();
      return res.status(401).json({ error: 'Utente non autenticato' });
    }

    const review = await SpotReview.findOne({ where: { id: reviewId, spotId }, transaction: t, lock: t.LOCK.UPDATE });
    if (!review) {
      await t.rollback();
      return res.status(404).json({ error: 'Recensione non trovata' });
    }

    if (String(review.userId) !== String(userId)) {
      await t.rollback();
      return res.status(403).json({ error: 'Non autorizzato' });
    }

    await review.destroy({ transaction: t });
    await recomputeSpotRating(spotId, t);
    await t.commit();

    return res.sendStatus(204);
  } catch (err) {
    try { await t.rollback(); } catch (_) {}
    return next(err);
  }
});

module.exports = router;