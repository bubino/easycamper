const jwt = require('jsonwebtoken');
function generateToken(user) {
  return jwt.sign(user, process.env.JWT_SECRET);
}
module.exports = { generateToken };
