// Mock di nodemailer per i test
module.exports = {
  createTransport: () => ({
    sendMail: jest.fn().mockResolvedValue({
      accepted: ['test@example.com'],
      rejected: [],
      response: '250 OK: queued'
    })
  })
};
