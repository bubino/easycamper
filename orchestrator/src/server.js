const express = require('express');
const cors = require('cors');
const axios = require('axios');
const pino = require('pino');

const logger = pino({ level: process.env.LOG_LEVEL || 'info' });
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
    for (const [shard, { bounds }] of Object.entries(shards)) {
        const [minLon, minLat, maxLon, maxLat] = bounds;
        if (lon >= minLon && lon <= maxLon && lat >= minLat && lat <= maxLat) {
            logger.info(`Punto [${lat}, ${lon}] assegnato allo shard ${shard}`);
            return shards[shard];
        }
    }
    logger.warn(`Punto [${lat}, ${lon}] fuori dai limiti geografici. Nessuno shard trovato.`);
    return null;
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
app.use(express.json()); // Middleware per il parsing del JSON

// Endpoint per la root
app.get('/', (req, res) => {
    res.send('Orchestrator is running!');
});

app.post('/route', async (req, res) => {
    const { points, profile } = req.body;
    logger.info({ points, profile }, 'Richiesta di percorso multi-shard ricevuta');

    try {
        if (!points || points.length < 2 || !profile) {
            logger.warn({ points, profile }, 'Richiesta non valida: parametri insufficienti.');
            return res.status(400).json({ message: 'Parametri insufficienti.' });
        }

        // Normalizza i punti
        const normalizedPoints = points.map(p => Array.isArray(p) ? p : p.split(',').map(Number));
        logger.info({ normalizedPoints }, 'Punti normalizzati');

        let finalPath = {
            distance: 0,
            time: 0,
            points: {
                type: "LineString",
                coordinates: []
            }
        };

        // Controlla se tutti i punti sono nello stesso shard
        const firstShard = getShard(normalizedPoints[0][1], normalizedPoints[0][0]);
        const allInSameShard = normalizedPoints.every(p => {
            const shard = getShard(p[1], p[0]);
            return shard && shard.url === firstShard.url;
        });

        if (allInSameShard) {
            logger.info('Tutti i punti si trovano nello stesso shard. Richiesta diretta allo shard.');
            const shardPoints = normalizedPoints.map(p => `${p[1]},${p[0]}`);
            try {
                const response = await axios.get(firstShard.url, {
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
                logger.info(`Risposta ricevuta da ${firstShard.url}:`, response.data);
                return res.json(response.data);
            } catch (err) {
                logger.error(`Errore dalla richiesta a ${firstShard.url}:`, err.response?.data || err.message);
                return res.status(500).json({ message: err.message });
            }
        }

        // Altrimenti, calcola il percorso attraverso gli shard
        logger.info('Calcolo del percorso attraverso più shard');
        let currentPoint = normalizedPoints[0];
        const endPoint = normalizedPoints[normalizedPoints.length - 1];
        const MAX_ITERATIONS = 10;

        for (let i = 0; i < MAX_ITERATIONS; i++) {
            if (getDistance(currentPoint, endPoint) < 1000) {
                logger.info("Destinazione finale raggiunta.");
                break;
            }

            const [currentLon, currentLat] = currentPoint;
            let shard = getShard(currentLat, currentLon);
            if (!shard) {
                logger.warn(`Punto corrente [${currentLat}, ${currentLon}] non assegnato a nessuno shard. Tentativo di assegnazione allo shard più vicino.`);
                // Assegna il punto allo shard più vicino
                let closestShard = null;
                let minDistance = Infinity;
                for (const s of Object.values(shards)) {
                    const [minLon, minLat, maxLon, maxLat] = s.bounds;
                    const shardCenterX = (minLon + maxLon) / 2;
                    const shardCenterY = (minLat + maxLat) / 2;
                    const d = getDistance([currentLon, currentLat], [shardCenterX, shardCenterY]);
                    if (d < minDistance) {
                        minDistance = d;
                        closestShard = s;
                    }
                }
                shard = closestShard;
                logger.warn({ point: [currentLat, currentLon], closestShard: shard.url }, `Punto corrente fuori da ogni mappa. Tento con lo shard più vicino.`);
            }

            let targetPointForShard = currentPoint;

            // Controlla se il punto corrente è vicino a un confine dello shard
            const [minLon, minLat, maxLon, maxLat] = shard.bounds;
            if (currentLon < minLon || currentLon > maxLon || currentLat < minLat || currentLat > maxLat) {
                // Calcola il punto di confine più vicino
                const borderLon = currentLon < minLon ? minLon : maxLon;
                const borderLat = currentLat < minLat ? minLat : maxLat;
                targetPointForShard = [borderLon, borderLat];
                logger.info({ target: targetPointForShard }, `Destinazione fuori dallo shard. Calcolo rotta verso il bordo.`);
            }

            logger.info({ from: currentPoint, to: targetPointForShard, shard: shard.url, iteration: i + 1 }, `Calcolo rotta parziale`);

            try {
                const response = await axios.get(shard.url, {
                    params: {
                        profile, // Profilo di routing
                        point: [currentPoint, targetPointForShard] // Due punti: corrente e destinazione
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

                if (!response.data || !response.data.paths || response.data.paths.length === 0) {
                    const warnMsg = response.data && response.data.message ? response.data.message : 'Nessun percorso valido trovato.';
                    logger.warn({ shard: shard.url, response: response.data }, `Risposta da GraphHopper non valida: ${warnMsg}. Termino il calcolo.`);
                    break;
                }

                const segmentPath = response.data.paths[0];

                // CORREZIONE: Aggiungi un controllo robusto per percorsi malformati
                if (!segmentPath || !segmentPath.points || !segmentPath.points.coordinates) {
                    logger.warn({ shard: shard.url, path: segmentPath }, `Segmento di percorso non valido o malformato ricevuto. Termino il calcolo.`);
                    break;
                }

                const segmentPoints = segmentPath.points.coordinates;

                if (segmentPoints.length < 2) {
                    logger.warn({ shard: shard.url, points: segmentPoints }, "Segmento di percorso troppo corto ricevuto, termino.");
                    break;
                }

                // Aggiungi i punti del segmento al percorso finale
                finalPath.distance += segmentPath.distance;
                finalPath.time += segmentPath.time;
                finalPath.points.coordinates.push(...segmentPoints);

                const lastPointOfSegment = segmentPoints[segmentPoints.length - 1];

                if (lastPointOfSegment[0] === currentPoint[0] && lastPointOfSegment[1] === currentPoint[1]) {
                    logger.warn({ point: currentPoint }, "Nessun progresso fatto, termino per evitare loop infiniti.");
                    break;
                }
                currentPoint = lastPointOfSegment;

            } catch (error) {
                const errorMessage = error.response ? JSON.stringify(error.response.data) : error.message;
                logger.error({ shard: shard.url, error: errorMessage, stack: error.stack }, `La richiesta allo shard è fallita`);
                throw new Error(`La richiesta allo shard ${shard.url} è fallita: ${errorMessage}`);
            }
        }

        if (finalPath.points.coordinates.length === 0) {
             logger.error({ startPoint: points[0] }, "Impossibile calcolare un percorso. Il punto di partenza potrebbe essere non valido.");
             return res.status(500).json({ message: "Impossibile calcolare un percorso. Il punto di partenza potrebbe essere non valido." });
        }

        // Assicurati che l'ultimo punto nel percorso finale sia il punto di arrivo desiderato
        const lastPointInPath = finalPath.points.coordinates[finalPath.points.coordinates.length - 1];
        if (lastPointInPath[0] !== endPoint[0] || lastPointInPath[1] !== endPoint[1]) {
            finalPath.points.coordinates.push(endPoint);
        }

        logger.info('Percorso finale calcolato con successo.');
        res.json({ paths: [finalPath] });

    } catch (error) {
        logger.error({ error: error.message, stack: error.stack }, "Errore fatale nell'endpoint /route");
        res.status(500).json({ message: error.message });
    }
});

app.listen(PORT, () => {
    logger.info(`Server in ascolto sulla porta ${PORT}`);
});