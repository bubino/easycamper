// server/config/config.js
require('dotenv').config();

module.exports = {
  development: {
    username: process.env.POSTGRES_USER     || 'easycamper',
    password: process.env.POSTGRES_PASSWORD || 'secret123',
    database: process.env.POSTGRES_DB       || 'easycamper_dev',
    host:     process.env.POSTGRES_HOST     || 'localhost',
    port:     process.env.POSTGRES_PORT     || 5432,
    dialect:  'postgres',
    logging:  false
  },
  test: {
    username: process.env.POSTGRES_USER,
    password: process.env.POSTGRES_PASSWORD,
    database: process.env.POSTGRES_DB       || 'easycamper_test',
    host:     process.env.POSTGRES_HOST,
    port:     process.env.POSTGRES_PORT,
    dialect:  'postgres',
    dialect: 'sqlite',
    storage: ':memory:',
    logging:  false
  },
  production: {
    username: process.env.POSTGRES_USER,
    password: process.env.POSTGRES_PASSWORD,
    database: process.env.POSTGRES_DB       || 'easycamper_prod',
    host:     process.env.POSTGRES_HOST,
    port:     process.env.POSTGRES_PORT,
    dialect:  'postgres',
    logging:  false
  }
};

