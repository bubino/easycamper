const request = require('supertest');
const app = require('../app');
const { findShard, getOrderedShardNames } = require('utils/shardUtils');
const { decodePolyline, encodePolyline, concatenatePolylines } = require('utils/polylineUtils');
const ghAxios = require('services/ghAxios'); // Ora si riferisce al mock globale

// Mock della configurazione per i test multi-shard
jest.mock('../config/config', () => ({
  graphhopper: {
    shards: {
      ovest: { name: 'ovest', url: 'http://gh_europa_ovest_test:8989', bbox: { lonMin: 5, lonMax: 8, latMin: 40, latMax: 50 } },
      centro: { name: 'centro', url: 'http://gh_europa_centro_test:8989', bbox: { lonMin: 8, lonMax: 12, latMin: 40, latMax: 50 } },
    },
  },
}));

// Mocking a valid encoded polyline
const validPolyline = '_p~iF~ps|U_ulLnnqC_mqNvxq';

describe('POST /api/route', () => {
  beforeEach(() => {
    // Resetta tutti i mock (inclusi quelli globali) prima di ogni test
    jest.resetAllMocks();
    // Imposta un valore di ritorno di default per encodePolyline per tutti i test
    encodePolyline.mockReturnValue(validPolyline);
  });

  it('should return a single-shard route correctly', async () => {
    // Setup dei mock per questo test specifico
    findShard.mockReturnValue({ name: 'centro', url: 'http://gh_europa_centro_test:8989' });
    // Usa il formato [lat, lon] corretto
    decodePolyline.mockReturnValue([[47.1, 9.5]]);
    ghAxios.get.mockResolvedValue({
      data: {
        paths: [{
          points: 'any_encoded_string', // L'input non importa, decodePolyline è mockato
          distance: 1234,
          time: 123,
        }],
      },
    });

    const res = await request(app)
      .post('/api/route')
      .send({
        point: ['47.1,9.5', '47.2,9.6'],
        profile: 'camper',
      });

    expect(res.status).toBe(200);
    expect(res.body.paths[0].distance).toBe(1234);
    expect(ghAxios.get).toHaveBeenCalledTimes(1);
    expect(res.body.paths[0].points).toBe('any_encoded_string');
  });

  it('should return a multi-shard route by merging results', async () => {
    // Setup per un percorso che attraversa due shard
    getOrderedShardNames.mockReturnValue(['ovest', 'centro']);
    findShard.mockImplementation((lat, lon) => {
      if (lon < 8) return { name: 'ovest', url: 'http://gh_europa_ovest_test:8989', bbox: { lonMin: 5, lonMax: 8, latMin: 40, latMax: 50 } };
      return { name: 'centro', url: 'http://gh_europa_centro_test:8989', bbox: { lonMin: 8, lonMax: 12, latMin: 40, latMax: 50 } };
    });

    // Mock delle risposte sequenziali da ghAxios
    ghAxios.get
      .mockResolvedValueOnce({ data: { paths: [{ points: 'poly1', distance: 1000, time: 100 }] } }) // Risposta da 'ovest'
      .mockResolvedValueOnce({ data: { paths: [{ points: 'poly2', distance: 2000, time: 200 }] } }); // Risposta da 'centro'

    // Pilotiamo i mock per questo scenario
    decodePolyline
      .mockReturnValueOnce([[1, 1]])
      .mockReturnValueOnce([[2, 2]]);
    concatenatePolylines.mockReturnValue([[1, 1], [2, 2]]);

    const res = await request(app)
      .post('/api/route')
      .send({
        point: ['49.5,6.0', '47.5,9.5'], // ovest -> centro
        profile: 'camper_eco',
      });

    expect(res.status).toBe(200);
    expect(res.body.paths[0].distance).toBe(3000); // 1000 + 2000
    expect(res.body.paths[0].time).toBe(300); // 100 + 200
    expect(ghAxios.get).toHaveBeenCalledTimes(2);
    expect(res.body.paths[0].points).toBe(validPolyline);
  });

  it('should handle polyline decoding errors gracefully', async () => {
    getOrderedShardNames.mockReturnValue(['ovest', 'centro']);
    findShard.mockImplementation((lat, lon) => {
      if (lon < 8) return { name: 'ovest', url: 'http://gh_europa_ovest_test:8989', bbox: { lonMin: 5, lonMax: 8, latMin: 40, latMax: 50 } };
      return { name: 'centro', url: 'http://gh_europa_centro_test:8989', bbox: { lonMin: 8, lonMax: 12, latMin: 40, latMax: 50 } };
    });

    // Pilotiamo il mock per lanciare un errore
    decodePolyline
      .mockImplementationOnce(() => { throw new Error('Invalid polyline'); })
      .mockReturnValueOnce([[2, 2]]);

    ghAxios.get
      .mockResolvedValueOnce({ data: { paths: [{ points: 'invalid_polyline', distance: 1000, time: 100 }] } })
      .mockResolvedValueOnce({ data: { paths: [{ points: 'valid_polyline', distance: 2000, time: 200 }] } });
    
    concatenatePolylines.mockReturnValue([[2, 2]]);

    const res = await request(app)
      .post('/api/route')
      .send({
        point: ['49.5,6.0', '47.5,9.5'],
      });
    
    expect(res.status).toBe(200);
    // La distanza e il tempo totali dovrebbero comunque essere calcolati
    expect(res.body.paths[0].distance).toBe(3000);
    // La polyline risultante dovrebbe essere solo quella valida
    expect(res.body.paths[0].points).toBe(validPolyline);
    expect(ghAxios.get).toHaveBeenCalledTimes(2);
  });

  it('should return a 400 if start or end point is outside covered areas', async () => {
    findShard.mockReturnValue(null); // Simula un punto non trovato
    const res = await request(app)
      .post('/api/route')
      .send({
        point: ['0,0', '1,1'],
      });
    expect(res.status).toBe(400);
    expect(res.body.message).toContain('Punto di partenza o arrivo fuori dalle aree coperte.');
  });
});