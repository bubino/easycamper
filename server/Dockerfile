FROM node:18-slim

WORKDIR /usr/src/app

# Installa le dipendenze di Node.js (incluse devDependencies per dotenv-cli)
COPY package*.json ./
RUN npm install
RUN npm install dotenv # <--- installa dotenv esplicitamente

# Copia il resto del codice della tua applicazione
COPY . .

# Copia il file openapi.yaml nella posizione richiesta dall'applicazione
COPY openapi.yaml /usr/src/api/easycamper/openapi.yaml

# Esponi la porta su cui la tua app Express è in ascolto
EXPOSE 3000

# Comando per eseguire l'applicazione
CMD [ "npm", "run", "dev" ]