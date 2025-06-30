# Usa un'immagine Node.js leggera
FROM node:18-alpine

# Crea la directory di lavoro
WORKDIR /usr/src/app

# Copia il file package.json e installa le dipendenze
COPY package.json package-lock.json ./
RUN npm install

# Copia il codice sorgente dell'applicazione
COPY src ./src

# Esponi la porta su cui il server sarà in ascolto
EXPOSE 3001

# Comando per avviare l'applicazione
CMD [ "node", "src/server.js" ]