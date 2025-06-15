// middleware/validateSpot.js
const { body } = require('express-validator');

const validateSpot = [
  body('name')
    .notEmpty().withMessage('Il nome è obbligatorio'),
  body('latitude')
    .isFloat({ min: -90, max: 90 }).withMessage('Latitudine non valida'),
  body('longitude')
    .isFloat({ min: -180, max: 180 }).withMessage('Longitudine non valida'),
  body('accessible')
    .optional()
    .isBoolean().withMessage('Il campo accessible deve essere booleano'),
  body('public')
    .optional()
    .isBoolean().withMessage('Il campo public deve essere booleano'),
  body('services')
    .optional()
    .isString().withMessage('Il campo services deve essere una stringa separata da virgole'),
  body('features')
    .optional()
    .isString().withMessage('Il campo features deve essere una stringa separata da virgole'),
];

module.exports = { validateSpot };
