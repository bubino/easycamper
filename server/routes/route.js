const express = require('express');
const router = express.Router();
const config = require('../config/config');
const { findShard, getOrderedShardNames } = require('utils/shardUtils');
const { decodePolyline, encodePolyline, concatenatePolylines } = require('utils/polylineUtils');
const { error: logError } = require('utils/logger');
const ghAxios = require('services/ghAxios');

/**
 * @module route
 * @description Questo modulo gestisce il calcolo dei percorsi, includendo una logica
 * avanzata per il routing multi-shard.
 *
 * La logica di routing multi-shard opera come segue:
 * 1.  **Identificazione Shard**: Determina gli shard di partenza e di arrivo
 *     basandosi sulle coordinate geografiche.
 * 2.  **Ordinamento Shard**: Se il percorso attraversa più shard, calcola l'ordine
 *     sequenziale degli shard da attraversare (es. ovest -> centro -> sud-est).
 * 3.  **Calcolo Iterativo**: Itera attraverso la sequenza di shard:
 *     a.  **Calcolo Punto di Confine**: Per ogni shard intermedio, non calcola il percorso
 *         fino alla destinazione finale, ma fino al punto di intersezione con il confine
 *         dello shard successivo. Questo viene fatto dalla funzione `borderIntersection`,
 *         che implementa un'intersezione parametrica tra il segmento (punto corrente ->
 *         destinazione finale) e il lato di confine dello shard.
 *     b.  **Richiesta a GraphHopper**: Invia la richiesta di routing per il segmento
 *         calcolato all'istanza di GraphHopper competente per quello shard.
 *     c.  **Aggregazione Risultati**: Concatena le polyline, le istruzioni di navigazione
 *         e somma le distanze e i tempi di ogni segmento.
 * 4.  **Risposta Finale**: Una volta percorsi tutti i segmenti, restituisce un'unica
 *     rotta combinata all'utente.
 * 5.  **Gestione Errori**: Se la polyline restituita da uno shard non è decodificabile,
 *     l'errore viene loggato ma il processo continua, garantendo la resilienza del sistema.
 */

function sharedSide(cur, next) {
  const a = cur.bbox, b = next.bbox;
  if (Math.abs(b.lonMin - a.lonMax) < 1e-4) return 'E';
  if (Math.abs(b.lonMax - a.lonMin) < 1e-4) return 'W';
  if (Math.abs(b.latMin - a.latMax) < 1e-4) return 'N';
  if (Math.abs(b.latMax - a.latMin) < 1e-4) return 'S';
  throw new Error(`Shard ${cur.name} non contiguo a ${next.name}`);
}

function borderIntersection(p1, p2, side, bbox) {
  let t;
  switch (side) {
    case 'E': {
      const lon = bbox.lonMax;
      if (Math.abs(p2.lon - p1.lon) < 1e-7) return { lon, lat: p1.lat };
      t = (lon - p1.lon) / (p2.lon - p1.lon);
      return { lon, lat: p1.lat + (p2.lat - p1.lat) * t };
    }
    case 'W': {
      const lon = bbox.lonMin;
      if (Math.abs(p2.lon - p1.lon) < 1e-7) return { lon, lat: p1.lat };
      t = (lon - p1.lon) / (p2.lon - p1.lon);
      return { lon, lat: p1.lat + (p2.lat - p1.lat) * t };
    }
    case 'N': {
      const lat = bbox.latMax;
      if (Math.abs(p2.lat - p1.lat) < 1e-7) return { lat, lon: p1.lon };
      t = (lat - p1.lat) / (p2.lat - p1.lat);
      return { lat, lon: p1.lon + (p2.lon - p1.lon) * t };
    }
    case 'S': {
      const lat = bbox.latMin;
      if (Math.abs(p2.lat - p1.lat) < 1e-7) return { lat, lon: p1.lon };
      t = (lat - p1.lat) / (p2.lat - p1.lat);
      return { lat, lon: p1.lon + (p2.lon - p1.lon) * t };
    }
  }
}

async function route(req, res, next) {
  const { point, profile, details, instructions } = req.body;
  try {
    // La logica ora è unificata, ma l'ambiente di test userà gli URL degli stub
    const startPoint = { lat: parseFloat(point[0].split(',')[0]), lon: parseFloat(point[0].split(',')[1]) };
    const endPoint = { lat: parseFloat(point[1].split(',')[0]), lon: parseFloat(point[1].split(',')[1]) };

    const startShard = findShard(startPoint.lat, startPoint.lon);
    const endShard = findShard(endPoint.lat, endPoint.lon);

    if (!startShard || !endShard) {
      return res.status(400).json({ message: 'Punto di partenza o arrivo fuori dalle aree coperte.' });
    }

    // Se il percorso è all'interno di un singolo shard, esegui una richiesta diretta
    if (startShard.name === endShard.name) {
      const params = {
        profile: profile || 'camper',
        points_encoded: true,
        point,
        details,
        instructions,
      };
      const response = await ghAxios.get(`${startShard.url}/route`, { params });
      return res.json(response.data);
    }

    // Logica per il routing multi-shard (usata sia in test che in produzione)
    const shardOrder = getOrderedShardNames(startShard.name, endShard.name);

    let segmentStart = startPoint;
    const finalDestination = endPoint;
    let fullCoords = [];
    let fullInstructions = [];
    let totalDistance = 0;
    let totalTime = 0;

    for (let i = 0; i < shardOrder.length; i++) {
      const shardName = shardOrder[i];
      const shardCfg = config.graphhopper.shards[shardName];
      const isLast = i === shardOrder.length - 1;
      let segmentEnd;

      if (isLast) {
        segmentEnd = finalDestination;
      } else {
        const nextShardName = shardOrder[i + 1];
        const nextShardCfg = config.graphhopper.shards[nextShardName];
        const side = sharedSide(shardCfg, nextShardCfg);
        segmentEnd = borderIntersection(segmentStart, finalDestination, side, shardCfg.bbox);
      }

      const params = {
        profile: profile || 'camper',
        points_encoded: true,
        point: [`${segmentStart.lat},${segmentStart.lon}`, `${segmentEnd.lat},${segmentEnd.lon}`],
        details: details || ['distance', 'time'],
        instructions: instructions === undefined ? true : instructions,
      };

      const url = `${shardCfg.url}/route`;
      const resp = await ghAxios.get(url, { params });

      if (!resp.data || !resp.data.paths || resp.data.paths.length === 0) {
        throw new Error(`Risposta invalida o vuota da GraphHopper shard: ${shardName}`);
      }
      const path = resp.data.paths[0];

      let segmentCoords;
      try {
        segmentCoords = decodePolyline(path.points);
      } catch (e) {
        logError({
          message: `Errore decodifica polyline dallo shard ${shardName}`,
          polyline: path.points,
          error: e,
        });
        segmentCoords = []; // Procedi con un segmento vuoto per non bloccare il percorso
      }

      if (fullCoords.length === 0) {
        fullCoords = segmentCoords;
      } else {
        fullCoords = concatenatePolylines(fullCoords, segmentCoords);
      }

      if (path.instructions) {
        fullInstructions.push(...path.instructions);
      }
      totalDistance += path.distance;
      totalTime += path.time;

      segmentStart = segmentEnd;
    }

    return res.json({
      paths: [{
        points: encodePolyline(fullCoords),
        instructions: fullInstructions,
        distance: totalDistance,
        time: totalTime,
      }],
    });
  } catch (err) {
    logError({ error: err.message, stack: err.stack, requestBody: req.body }, 'Errore nel routing API');
    next(err);
  }
}

router.post('/', route);

module.exports = router;
