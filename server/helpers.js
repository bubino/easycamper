// helpers.js
const { validationResult } = require('express-validator');

function asyncHandler(fn) {
  return (req, res, next) =>
    Promise.resolve(fn(req, res, next)).catch(next);
}

function validate(req, res, next) {
  const errs = validationResult(req);
  if (!errs.isEmpty()) {
    return res.status(400).json({
      errors: errs.array().map(e => ({ field: e.param, msg: e.msg }))
    });
  }
  next();
}

module.exports = { asyncHandler, validate };

