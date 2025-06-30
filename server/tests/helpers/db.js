require('dotenv').config({ path: '.env.test' });
const jwt  = require('jsonwebtoken');
const { User } = require('../../models');

// Seed di un utente fittizio e ritorno del token JWT
async function seedUser() {
  const userData = { id: 'u1', username: 'test', email: 'test@example.com' };
  // creazione utente con password hash fittizia (non usata nella verify)
  await User.create({ ...userData, passwordHash: '<hash>' });
  // firma del token con lo stesso secret dei test
  return jwt.sign(userData, process.env.JWT_SECRET);
}

module.exports = { seedUser };
