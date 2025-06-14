'use strict';

const app  = require('./app');
const port = process.env.PORT || 3000;

app.listen(port, () => {
  console.log(`EasyCamper API in ascolto sulla porta ${port}`);
});