require('dotenv').config({ path: '.env.test' });
const jwt  = require('jsonwebtoken');
const { User } = require('../../models');

// Seed di un utente fittizio e ritorno del token JWT
async function seedUser() {
  const userData = { id: 'u1', username: 'test', email: 'test@example.com', password: 'testpass', emailVerified: true };
  await User.create(userData);
  // firma del token con lo stesso secret dei test
  return jwt.sign({ id: userData.id, username: userData.username, email: userData.email }, process.env.JWT_SECRET);
}

module.exports = { seedUser };
