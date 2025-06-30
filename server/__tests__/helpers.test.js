// __tests__/helpers.test.js

// 1) MOCK di express-validator PRIMA di require dei helper
jest.mock('express-validator', () => ({
  validationResult: jest.fn()
}));

const { validationResult } = require('express-validator');
const httpMocks       = require('node-mocks-http');
const { validate, asyncHandler } = require('../helpers'); // i tuoi helper

describe('validate middleware', () => {
  afterEach(() => {
    validationResult.mockReset();
  });

  it('dovrebbe inviare 400 se ci sono errori', () => {
    // configuro il mock per dire che ci sono errori
    validationResult.mockReturnValue({
      isEmpty: () => false,
      array:   () => [{ param: 'foo', msg: 'bar' }]
    });

    const req = httpMocks.createRequest();
    const res = httpMocks.createResponse();
    let nextCalled = false;

    validate(req, res, () => { nextCalled = true; });

    expect(res.statusCode).toBe(400);
    const data = JSON.parse(res._getData());
    expect(data.errors).toEqual([{ field: 'foo', msg: 'bar' }]);
    expect(nextCalled).toBe(false);
  });

  it('dovrebbe chiamare next se non ci sono errori', () => {
    // configuro il mock per dire che non ci sono errori
    validationResult.mockReturnValue({
      isEmpty: () => true,
      array:   () => []
    });

    const req = httpMocks.createRequest();
    const res = httpMocks.createResponse();
    let nextCalled = false;

    validate(req, res, () => { nextCalled = true; });

    expect(res._isEndCalled()).toBe(false);
    expect(nextCalled).toBe(true);
  });
});

describe('asyncHandler helper', () => {
  it('propaga errori al next', async () => {
    const err = new Error('fail');
    const wrapped = asyncHandler(() => Promise.reject(err));

    const req = httpMocks.createRequest();
    const res = httpMocks.createResponse();
    let caught;
    await wrapped(req, res, e => { caught = e; });

    expect(caught).toBe(err);
  });

  it('propaga la risposta normale se non ci sono errori', async () => {
    const spy = jest.fn((req, res, next) => res.send('ok'));
    const wrapped = asyncHandler(spy);

    const req = httpMocks.createRequest();
    const res = httpMocks.createResponse();
    let nextCalled = false;
    await wrapped(req, res, () => { nextCalled = true; });

    expect(res._getData()).toBe('ok');
    expect(nextCalled).toBe(false);
  });
});
