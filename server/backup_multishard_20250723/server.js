const express = require('express');
const cors = require('cors');
const axios = require('axios');

const app = express();
const PORT = 3001;

// Mappa degli shard e dei loro limiti geografici
const shards = {
    'europa-ovest': { url: 'http://gh_europa_ovest:8989/route', bounds: [-10.83, 35.85, 8.61, 59.20] },
    'europa-nord': { url: 'http://gh_europa_nord:8990/route', bounds: [2.46, 53.00, 31.50, 71.50] },
    'europa-sud': { url: 'http://gh_europa_sud:8991/route', bounds: [-10.00, 35.00, 18.80, 44.00] },
    'europa-centro': { url: 'http://gh_europa_centro:8992/route', bounds: [5.00, 44.00, 25.00, 55.00] },
    'europa-sud-est': { url: 'http://gh_europa_sud_est:8993/route', bounds: [12.50, 34.00, 30.00, 48.00] },
};

// Funzione per determinare lo shard corretto
function getShard(lat, lon) {
    let closestShard = null;
    let minDistance = Infinity;

    for (const [shard, { bounds }] of Object.entries(shards)) {
        const [minLon, minLat, maxLon, maxLat] = bounds;
        if (lon >= minLon && lon <= maxLon && lat >= minLat && lat <= maxLat) {
            console.log(`Punto assegnato allo shard ${shard} con bounds: [${minLon}, ${minLat}, ${maxLon}, ${maxLat}]`);
            return shards[shard];
        }

        // Calcola la distanza dal centro dello shard
        const centerLat = (minLat + maxLat) / 2;
        const centerLon = (minLon + maxLon) / 2;
        const distance = Math.sqrt((lat - centerLat) ** 2 + (lon - centerLon) ** 2);

        if (distance < minDistance) {
            minDistance = distance;
            closestShard = shards[shard];
        }
    }

    console.warn(`Punto fuori dai limiti geografici: lat=${lat}, lon=${lon}. Assegno lo shard più vicino.`);
    return closestShard;
}

// Funzione per unire i percorsi
function mergeRoutes(responses) {
    const mergedPath = {
        distance: 0,
        time: 0,
        points: []
    };

    responses.forEach(({ response }) => {
        const path = response.paths[0];
        mergedPath.distance += path.distance;
        mergedPath.time += path.time;

        // Aggiungi i punti del percorso, evitando duplicati
        if (mergedPath.points.length > 0) {
            mergedPath.points.pop(); // Rimuovi l'ultimo punto per evitare duplicati
        }
        mergedPath.points.push(...path.points.coordinates);
    });

    return mergedPath;
}

app.use(cors());

// Endpoint per la root
app.get('/', (req, res) => {
    res.send('Orchestrator is running!');
});

// Endpoint per il calcolo del percorso
app.get('/route', async (req, res) => {
    try {
        const { point, profile } = req.query;
        console.log('Richiesta ricevuta:', { point, profile });

        // Validazione dei parametri
        if (!point || !profile) {
            console.error('Parametri mancanti:', { point, profile });
            return res.status(400).json({ message: 'Parametri mancanti: sono richiesti almeno 2 punti e un profilo.' });
        }

        // Normalizza i punti
        const points = Array.isArray(point) ? point : [point];
        if (points.length < 2) {
            console.error('Parametri insufficienti: sono richiesti almeno 2 punti.');
            return res.status(400).json({ message: 'Parametri insufficienti: sono richiesti almeno 2 punti.' });
        }

        const shardRequests = {};

        // Raggruppa i punti per shard
        points.forEach((p, index) => {
            const [lat, lon] = p.split(',').map(Number);
            console.log(`Punto ricevuto: lat=${lat}, lon=${lon}`);
            const shard = getShard(lat, lon);
            if (!shard) {
                console.error(`Punto fuori dai limiti geografici: ${p}`);
                throw new Error(`Punto fuori dai limiti geografici: ${p}. Verifica i dati caricati negli shard.`);
            }
            console.log(`Shard selezionato per ${p}: ${shard.url}`);
            if (!shardRequests[shard.url]) {
                shardRequests[shard.url] = [];
            }
            shardRequests[shard.url].push({ index, lat, lon });
        });

        // Verifica che ogni shard abbia almeno due punti
        Object.entries(shardRequests).forEach(([url, points]) => {
            if (points.length < 2) {
                console.warn(`Shard ${url} ha meno di due punti. Aggiungo un punto fittizio.`);
                const [firstPoint] = points;
                points.push({ ...firstPoint }); // Duplica il primo punto per soddisfare il requisito
            }
        });

        // Esegui richieste parallele agli shard
        const responses = await Promise.allSettled(
            Object.entries(shardRequests).map(async ([url, points]) => {
                const shardPoints = points.map(p => `${p.lat},${p.lon}`);
                console.log(`Inoltro richiesta a ${url} con punti:`, shardPoints);
                try {
                    const response = await axios.get(url, {
                        params: {
                            profile, // Profilo di routing
                            point: shardPoints // Array di punti
                        },
                        paramsSerializer: params => {
                            // Serializza i parametri per inviarli come array di query string
                            return Object.entries(params)
                                .map(([key, value]) =>
                                    Array.isArray(value)
                                        ? value.map(v => `${key}=${encodeURIComponent(v)}`).join('&')
                                        : `${key}=${encodeURIComponent(value)}`
                                )
                                .join('&');
                        }
                    });
                    console.log(`Risposta ricevuta da ${url}:`, response.data);
                    return { url, response: response.data };
                } catch (err) {
                    console.error(`Errore dalla richiesta a ${url}:`, err.response?.data || err.message);
                    return { url, error: err.message };
                }
            })
        );

        // Combina i risultati
        const successfulResponses = responses.filter(r => r.status === 'fulfilled').map(r => r.value);
        const mergedRoute = mergeRoutes(successfulResponses);

        console.log('Percorso unito:', mergedRoute);
        res.json(mergedRoute);

    } catch (error) {
        console.error('Errore durante il calcolo del percorso:', error.message);
        res.status(500).json({ message: error.message });
    }
});

app.listen(PORT, () => {
    console.log(`Server in ascolto sulla porta ${PORT}`);
});