const { body } = require('express-validator');

exports.validateVehicle = [
  body('type').isIn(['camper', 'van', 'motorhome']).withMessage('Tipo veicolo non valido'),
  body('make').notEmpty().withMessage('Marca obbligatoria'),
  body('model').notEmpty().withMessage('Modello obbligatorio'),
  body('year').optional().isInt({ min: 1900 }).withMessage('Anno non valido'),
  body('height').optional().isFloat({ min: 0 }),
  body('length').optional().isFloat({ min: 0 }),
  body('weight').optional().isFloat({ min: 0 })
];
