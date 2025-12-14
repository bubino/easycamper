process.env.JWT_SECRET = 'testsecret';

// Mock globali per servizi esterni
jest.mock('services/ghAxios');
jest.mock('utils/polylineUtils');
jest.mock('utils/shardUtils');
jest.mock('nodemailer'); // Riattivato mock nodemailer per ambiente di test

// Mock globale robusto per fetch
import 'whatwg-fetch';

// Se vuoi controllare le risposte nei test:
jest.spyOn(global, 'fetch').mockImplementation((...args) => {
  // Puoi personalizzare qui la risposta di default
  return Promise.resolve({
    ok: true,
    status: 200,
    json: async () => ({}),
    text: async () => '',
  });
});