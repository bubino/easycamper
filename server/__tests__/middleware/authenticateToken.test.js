const httpMocks = require('node-mocks-http');
const authenticateToken = require('../../middleware/authenticateToken');

describe('authenticateToken middleware', () => {
    test('valid token', () => {
        const req = httpMocks.createRequest({
            headers: {
                authorization: 'Bearer validToken'
            }
        });
        const res = httpMocks.createResponse();
        const next = jest.fn();

        authenticateToken(req, res, next);

        expect(next).toHaveBeenCalled();
    });

    test('invalid token', () => {
        const req = httpMocks.createRequest({
            headers: {
                authorization: 'Bearer invalidToken'
            }
        });
        const res = httpMocks.createResponse();
        const next = jest.fn();

        authenticateToken(req, res, next);

        expect(res.statusCode).toBe(403);
        expect(res._getData()).toBe('Forbidden');
        expect(next).not.toHaveBeenCalled();
    });

    test('missing token', () => {
        const req = httpMocks.createRequest();
        const res = httpMocks.createResponse();
        const next = jest.fn();

        authenticateToken(req, res, next);

        expect(res.statusCode).toBe(401);
        expect(res._getData()).toBe('Unauthorized');
        expect(next).not.toHaveBeenCalled();
    });
});