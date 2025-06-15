// index.js
const app = require('./app');
const { sequelize } = require('./models');

(async () => {
  // in test Jest esegue sempre sync({ force: true })
  await sequelize.sync({ force: process.env.NODE_ENV === 'test' });
  if (process.env.NODE_ENV !== 'test') {
    const port = process.env.PORT || 3000;
    app.listen(port, () => console.log(`Listening on port ${port}`));
  }
})();
