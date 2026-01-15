const express = require('express');
const router = express.Router();

const db = require('../models');
const { VehicleModel } = db;

// GET /api/vehicle-models?search=&brand=&limit=&offset=
router.get('/', async (req, res) => {
  try {
    const { search, brand, limit = 20, offset = 0 } = req.query;

    const where = {};
    const { Op, fn, col, where: whereFn } = db.Sequelize;

    const q = typeof search === 'string' ? search.trim() : '';
    const b = typeof brand === 'string' ? brand.trim() : '';

    if (q) {
      // Case-insensitive search without relying on Postgres-only ILIKE.
      // Postgres: lower(col) LIKE lower('%q%')
      // This keeps behavior stable via Docker/Postgres and is safe to keep even if SQLite is used in unit tests.
      const like = `%${q.toLowerCase()}%`;
      where[Op.or] = [
        whereFn(fn('lower', col('brand')), { [Op.like]: like }),
        whereFn(fn('lower', col('model')), { [Op.like]: like }),
      ];
    }

    if (b) {
      const like = `%${b.toLowerCase()}%`;
      where.brand = whereFn(fn('lower', col('brand')), { [Op.like]: like });
    }

    const parsedLimit = Math.min(parseInt(limit, 10) || 20, 100);
    const parsedOffset = parseInt(offset, 10) || 0;

    const { rows, count } = await VehicleModel.findAndCountAll({
      where,
      limit: parsedLimit,
      offset: parsedOffset,
      order: [['brand', 'ASC'], ['model', 'ASC']],
    });

    res.json({
      data: rows,
      total: count,
      limit: parsedLimit,
      offset: parsedOffset,
    });
  } catch (err) {
    console.error('Errore in GET /api/vehicle-models', err);
    res.status(500).json({ error: 'Errore interno' });
  }
});

module.exports = router;
