// carica le variabili d’ambiente (.env, .env.development, .env.test …)
require('dotenv').config();

module.exports = {
  // ----------- sviluppo locale -------------------------------------------
  development: {
    username: process.env.POSTGRES_USER     || 'easycamper',
    password: process.env.POSTGRES_PASSWORD || 'secret123',
    database: process.env.POSTGRES_DB       || 'easycamper_dev',
    host:     process.env.POSTGRES_HOST     || 'db',
    port:     process.env.POSTGRES_PORT     || 5432,
    dialect:  'postgres',
    logging:  false
  },

  // ----------- ambiente di test (Jest) -----------------------------------
  // Decisione progetto: test su Postgres (docker-compose.test.yml).
  test: {
    username: process.env.POSTGRES_USER     || 'easycamper',
    password: process.env.POSTGRES_PASSWORD || 'secret123',
    database: process.env.POSTGRES_DB       || 'easycamper_test',
    host:     process.env.POSTGRES_HOST     || '127.0.0.1',
    port:     process.env.POSTGRES_PORT     || 5433,
    dialect:  'postgres',
    logging:  false
  },

  // ----------- ambiente di test end-to-end (E2E) --------------------------
  e2e: {
    username: process.env.POSTGRES_USER     || 'easycamper',
    password: process.env.POSTGRES_PASSWORD || 'secret123',
    database: process.env.POSTGRES_DB       || 'easycamper_test',
    host:     process.env.POSTGRES_HOST     || '127.0.0.1',
    port:     process.env.POSTGRES_PORT     || 5433,
    dialect:  'postgres',
    logging:  false
  },

  // ----------- produzione ------------------------------------------------
  production: {
    username: process.env.POSTGRES_USER,
    password: process.env.POSTGRES_PASSWORD,
    database: process.env.POSTGRES_DB       || 'easycamper_prod',
    host:     process.env.POSTGRES_HOST,
    port:     process.env.POSTGRES_PORT,
    dialect:  'postgres',
    logging:  false
  },

  graphhopper: {
    shards: {
      nord: {
        url: process.env.GH_NORD_URL || 'http://localhost:8989',
        bbox: { latMin: 50.0, latMax: 90.0, lonMin: -10.0, lonMax: 40.0 }
      },
      centro: {
        url: process.env.GH_CENTRO_URL || 'http://localhost:8990',
        bbox: { latMin: 40.0, latMax: 50.0, lonMin: -10.0, lonMax: 40.0 }
      },
      sud: {
        url: process.env.GH_SUD_URL || 'http://localhost:8991',
        bbox: { latMin: -90.0, latMax: 40.0, lonMin: -10.0, lonMax: 40.0 }
      }
    },
    logicalOrder: [
      'nord',
      'centro',
      'sud'
    ]
  }
};