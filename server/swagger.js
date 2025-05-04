// swagger.js
const swaggerJSDoc = require('swagger-jsdoc');

const options = {
  definition: {
    openapi: '3.0.0',
    info: {
      title: 'Easycamper API',
      version: '1.0.0',
      description: 'Documentazione delle rotte REST di Easycamper'
    },
    servers: [
      {
        url: `http://localhost:${process.env.PORT || 3000}`,
        description: 'Dev server'
      }
    ],
    components: {
      securitySchemes: {
        bearerAuth: {
          type: 'http',
          scheme: 'bearer',
          bearerFormat: 'JWT'
        }
      },
      schemas: {
        Vehicle: {
          type: 'object',
          properties: {
            id:        { type: 'string' },
            userId:    { type: 'string' },
            type:      { type: 'string', enum: ['camper','van','motorhome'] },
            make:      { type: 'string' },
            model:     { type: 'string' },
            height:    { type: 'number', nullable: true },
            length:    { type: 'number', nullable: true },
            weight:    { type: 'number', nullable: true },
            imageUrl:  { type: 'string', nullable: true },
            createdAt: { type: 'string', format: 'date-time' },
            updatedAt: { type: 'string', format: 'date-time' }
          }
        },
        Spot: {
          type: 'object',
          properties: {
            id:          { type: 'string' },
            userId:      { type: 'string' },
            name:        { type: 'string' },
            description: { type: 'string', nullable: true },
            latitude:    { type: 'number' },
            longitude:   { type: 'number' }
          }
        },
        MaintenanceEntry: {
          type: 'object',
          properties: {
            id:        { type: 'string' },
            vehicleId: { type: 'string' },
            date:      { type: 'string', format: 'date' },
            type:      { type: 'string', enum: ['tagliando','riparazione','controllo'] },
            notes:     { type: 'string', nullable: true },
            createdAt: { type: 'string', format: 'date-time' },
            updatedAt: { type: 'string', format: 'date-time' }
          }
        }
      }
    },
    security: [
      {
        bearerAuth: []
      }
    ]
  },
  apis: [
    './index.js',
    './models/*.js'
  ]
};

const swaggerSpec = swaggerJSDoc(options);
module.exports = swaggerSpec;
