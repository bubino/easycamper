jest.mock('axios');
jest.mock('../utils/polylineUtils');

const axios = require('axios');
// Create GH axios mock with interceptors for retry
const ghAxiosMock = {
  get: jest.fn(),
  interceptors: { request: { use: jest.fn() }, response: { use: jest.fn() } }
};
// Setup axios retry helpers and create
axios.isNetworkError = jest.fn(() => false);
axios.isRetryableError = jest.fn(() => false);
axios.create = jest.fn(() => ghAxiosMock);

const { decodePolyline, encodePolyline, concatenatePolylines } = require('../utils/polylineUtils');
const request = require('supertest');
const app = require('../app');

describe('GET /api/route Windeck→Bolzano multi-shard', () => {
  beforeAll(() => {
    // Mock axios.create to return ghAxios-like instance
    // First segment response
    ghAxiosMock.get
      .mockResolvedValueOnce({ data: { paths: [{ points: 'p1', instructions: ['i1'], distance: 100, time: 10 }] } })
      .mockResolvedValueOnce({ data: { paths: [{ points: 'p2', instructions: ['i2'], distance: 200, time: 20 }] } });
    // polyline utils mocks: decode two segments, concat, encode
    decodePolyline
      .mockReturnValueOnce([[1,1],[2,2]])
      .mockReturnValueOnce([[2,2],[3,3]]);
    concatenatePolylines.mockImplementation((a, b) => [[1,1],[2,2],[3,3]]);
    encodePolyline.mockReturnValue('encoded_polyline');
  });

  it('should return merged route with correct sum and polyline', async () => {
    const res = await request(app)
      .get('/api/route')
      .query({
        point: ['50.8,7.5', '46.5,11.3'],
        profile: 'camper_eco',
        'dimensions[height]': '3.0',
        'dimensions[width]': '2.0',
        'dimensions[length]': '7.0',
        'dimensions[weight]': '3.5'
      });

    expect(res.status).toBe(200);
    expect(res.body).toHaveProperty('paths');
    const path = res.body.paths[0];
    expect(path.points).toBe('encoded_polyline');
    expect(path.instructions).toEqual(['i1','i2']);
    expect(path.distance).toBe(300);
    expect(path.time).toBe(30);
    // axios.create should be called once, and get twice
    expect(axios.create).toHaveBeenCalled();
    const ghAxios = axios.create.mock.results[0].value;
    expect(ghAxios.get).toHaveBeenCalledTimes(2);
  });
});