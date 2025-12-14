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

async function sendEmailChangeNotification({ oldEmail, newEmail, username }) {
  const transporter = nodemailer.createTransport({
    host: process.env.SMTP_HOST || 'smtp.example.com',
    port: process.env.SMTP_PORT || 587,
    secure: false,
    auth: {
      user: process.env.SMTP_USER || 'user',
      pass: process.env.SMTP_PASS || 'pass'
    }
  });
  // Notifica al vecchio indirizzo
  await transporter.sendMail({
    from: 'noreply@easycamper.com',
    to: oldEmail,
    subject: 'Il tuo indirizzo email è stato cambiato',
    html: `<p>Ciao ${username},</p><p>Il tuo indirizzo email su EasyCamper è stato cambiato da <b>${oldEmail}</b> a <b>${newEmail}</b> il 24 luglio 2025. Se non sei stato tu, contatta subito il supporto.</p>`
  });
  // Notifica al nuovo indirizzo
  await transporter.sendMail({
    from: 'noreply@easycamper.com',
    to: newEmail,
    subject: 'Benvenuto sul nuovo indirizzo email',
    html: `<p>Ciao ${username},</p><p>Questa email conferma che il tuo nuovo indirizzo <b>${newEmail}</b> è ora attivo su EasyCamper.</p>`
  });
}

async function sendEmailChangeRequest({ newEmail, username, token }) {
  const transporter = nodemailer.createTransport({
    host: process.env.SMTP_HOST || 'smtp.example.com',
    port: process.env.SMTP_PORT || 587,
    secure: false,
    auth: {
      user: process.env.SMTP_USER || 'user',
      pass: process.env.SMTP_PASS || 'pass'
    }
  });
  const confirmUrl = `${process.env.BASE_URL || 'http://localhost:3000'}/users/confirm-email-change?token=${token}`;
  await transporter.sendMail({
    from: 'noreply@easycamper.com',
    to: newEmail,
    subject: 'Conferma il cambio email su EasyCamper',
    html: `<p>Ciao ${username || newEmail},</p><p>Per confermare il cambio email clicca <a href="${confirmUrl}">qui</a>.<br>Se non hai richiesto tu questa operazione, ignora questa email.</p>`
  });
}

module.exports = {
  sendVerificationEmail,
  sendResetPasswordEmail,
  sendEmailChangeNotification,
  sendEmailChangeRequest
};