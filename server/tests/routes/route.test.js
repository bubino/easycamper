/* eslint-env jest */

// Mock dei moduli per garantire la stabilità del test di integrazione
jest.mock('utils/polylineUtils');
jest.mock('utils/shardUtils');
jest.mock('services/ghAxios');

require('dotenv').config({ path: '.env.test' });
const request = require('supertest');
const { sequelize } = require('../../models');
const app = require('../../app');
const { seedUser } = require('../helpers/db');

// Importa i moduli usando gli stessi path non relativi dei mock
const { findShard } = require('utils/shardUtils');
const { encodePolyline, decodePolyline, concatenatePolylines } = require('utils/polylineUtils');
const ghAxios = require('services/ghAxios');

let token;
const validPolyline = '_p~iF~ps|U_ulLnnqC_mqNvxq';

beforeAll(async () => {
  jest.setTimeout(30000);
  await sequelize.sync({ force: true });
  token = await seedUser();
});

afterAll(async () => {
  await sequelize.close();
});

describe('POST /api/route', () => {
  
  beforeEach(() => {
    jest.resetAllMocks();
    // Forniamo implementazioni di base per i mock per ogni test
    findShard.mockReturnValue({ name: 'centro', url: 'http://gh_europa_centro_test:8989' });
    ghAxios.get.mockResolvedValue({
      data: {
        paths: [{
          points: validPolyline, // 1. Restituisce la polyline valida
          distance: 1234,
          time: 123,
        }],
      },
    });
    // 2. Decodifica le coordinate reali usate nel test
    decodePolyline.mockReturnValue([[47.14, 9.52], [47.20, 9.55]]);
    concatenatePolylines.mockReturnValue([[0, 0]]);
    encodePolyline.mockReturnValue(validPolyline);
  });

  it('should create a new route within a single shard (centro)', async () => {
    const response = await request(app)
      .post('/api/route')
      .set('Authorization', `Bearer ${token}`)
      .send({
        point: ['47.14,9.52', '47.20,9.55'],
        profile: 'camper',
      });
    const { body } = response;
    expect(response.status).toBe(200);
    expect(body).toBeDefined();
    expect(body).toHaveProperty('paths');
    // 3. Verifica che la polyline restituita sia quella corretta
    expect(body.paths[0].points).toBe(validPolyline);
  });
});
