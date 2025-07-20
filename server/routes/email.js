const nodemailer = require('nodemailer');

async function sendVerificationEmail(user, verificationToken) {
  const transporter = nodemailer.createTransport({
    host: process.env.SMTP_HOST || 'smtp.example.com',
    port: process.env.SMTP_PORT || 587,
    secure: false,
    auth: {
      user: process.env.SMTP_USER || 'user',
      pass: process.env.SMTP_PASS || 'pass'
    }
  });
  const verifyUrl = `${process.env.BASE_URL || 'http://localhost:3000'}/auth/verify-email?token=${verificationToken}`;
  await transporter.sendMail({
    from: 'noreply@easycamper.com',
    to: user.email,
    subject: 'Verifica il tuo indirizzo email',
    html: `<p>Ciao ${user.username},</p><p>Conferma la tua email cliccando <a href="${verifyUrl}">qui</a>.</p>`
  });
}

async function sendResetPasswordEmail(user, resetToken) {
  const transporter = nodemailer.createTransport({
    host: process.env.SMTP_HOST || 'smtp.example.com',
    port: process.env.SMTP_PORT || 587,
    secure: false,
    auth: {
      user: process.env.SMTP_USER || 'user',
      pass: process.env.SMTP_PASS || 'pass'
    }
  });
  const resetUrl = `${process.env.BASE_URL || 'http://localhost:3000'}/auth/reset-password?token=${resetToken}`;
  await transporter.sendMail({
    from: 'noreply@easycamper.com',
    to: user.email,
    subject: 'Reset password EasyCamper',
    html: `<p>Ciao ${user.username},</p><p>Per reimpostare la password clicca <a href="${resetUrl}">qui</a>.</p>`
  });
}

module.exports = {
  sendVerificationEmail,
  sendResetPasswordEmail
};