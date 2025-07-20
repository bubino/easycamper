const path = require('path');
const YAML = require('yamljs'); // ← ti serve yamljs installato

// Carica la specifica OpenAPI dal file YAML
const swaggerDocument = YAML.load(
  path.join(__dirname, '..', 'api', 'easycamper', 'openapi.yaml')
);

module.exports = swaggerDocument;