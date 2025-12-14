const express = require('express');
const router = express.Router();

const db = require('../models');
const { VehicleModel } = db;

// GET /api/vehicle-models?search=&brand=&limit=&offset=
router.get('/', async (req, res) => {
  try {
    const { search, brand, limit = 20, offset = 0 } = req.query;

    const where = {};
    const { Op } = db.Sequelize;

    if (search) {
      where[Op.or] = [
        { brand: { [Op.iLike]: `%${search}%` } },
        { model: { [Op.iLike]: `%${search}%` } },
      ];
    }

    if (brand) {
      where.brand = { [Op.iLike]: `%${brand}%` };
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
