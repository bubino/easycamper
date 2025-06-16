const path = require('path');

require('dotenv').config({
  //  .. = esci da /services  →  /server/.env(.test)
  path: path.join(__dirname, '..',
    process.env.NODE_ENV === 'test' ? '.env.test' : '.env')
});