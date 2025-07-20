const express = require('express');
const axios = require('axios');
const axiosRetry = require('axios-retry').default;
const pino = require('pino');
const qs = require('qs');
const config = require('../config/config');
const { decodePolyline, encodePolyline, concatenatePolylines } = require('../utils/polylineUtils');
const router = express.Router();

const logger = pino({ level: process.env.LOG_LEVEL || 'info' });
// Axios instance with retry for GraphHopper, con paramsSerializer per arrayFormat=repeat
const ghAxios = axios.create({
  paramsSerializer: params => qs.stringify(params, { arrayFormat: 'repeat' })
});
axiosRetry(ghAxios, {
  retries: 3,
  retryDelay: retryCount => retryCount * 1000,
  retryCondition: error => axiosRetry.isNetworkError(error) || axiosRetry.isRetryableError(error),
  onRetry: (retryCount, error, requestConfig) => {
    logger.warn({ retryCount, url: requestConfig.url, message: error.message }, 'Retry GH request');
  }
});

// Trova lo shard a cui appartiene un punto
function findShard(point) {
  const { lat, lon } = point;
  for (const [name, shard] of Object.entries(config.graphhopper.shards)) {
    const { latMin, latMax, lonMin, lonMax } = shard.bbox;
    if (lat >= latMin && lat <= latMax && lon >= lonMin && lon <= lonMax) {
      return name;
    }
  }
  return null;
}

// Calcola il punto di confine lineare tra due punti su borderLat
function computeBorderPoint(p1, p2, borderLat) {
  if (Math.abs(p2.lat - p1.lat) < 1e-7) {
    return { lat: borderLat, lon: p1.lon };
  }
  const t = (borderLat - p1.lat) / (p2.lat - p1.lat);
  return { lat: borderLat, lon: p1.lon + (p2.lon - p1.lon) * t };
}

// Restituisce lista ordinata di shard da attraversare
function getOrderedShardNames(startShard, endShard) {
  const order = config.graphhopper.logicalOrder;
  const si = order.indexOf(startShard);
  const ei = order.indexOf(endShard);
  if (si < 0 || ei < 0) throw new Error(`Shard sconosciuto: ${startShard} o ${endShard}`);
  return si <= ei ? order.slice(si, ei + 1) : order.slice(ei, si + 1).reverse();
}

router.get('/', async (req, res, next) => {
  try {
    const rawPoints = ([]).concat(req.query.point);
    if (rawPoints.length < 2 || !req.query.profile) {
      return res.status(400).json({ error: 'Specify at least two points and a profile.' });
    }
    const pts = rawPoints.map(p => {
      const [lat, lon] = p.split(',').map(Number);
      return { lat, lon };
    });
    const { profile } = req.query;
    const dimensions = req.query.dimensions || {};

    // Determine shards to traverse
    const startShard = findShard(pts[0]);
    const endShard = findShard(pts[pts.length - 1]);
    if (!startShard || !endShard) {
      return res.status(400).json({ error: 'Punto fuori dall’area di copertura europea.' });
    }
    const shardOrder = getOrderedShardNames(startShard, endShard);
    // Direzione: avanti se start precede end
    const logical = config.graphhopper.logicalOrder;
    const isForward = logical.indexOf(startShard) <= logical.indexOf(endShard);

    // Common GH params
    const baseParams = {
      profile,
      details: 'distance,time,instructions',
      points_encoded: true,
      // attach camper dimensions if provided
      ...(dimensions.height && { 'ch.max_height': dimensions.height }),
      ...(dimensions.width && { 'ch.max_width': dimensions.width }),
      ...(dimensions.length && { 'ch.max_length': dimensions.length }),
      ...(dimensions.weight && { 'ch.max_weight': dimensions.weight })
    };

    // Traverse shards
    let fullCoords = [];
    let fullInstructions = [];
    let totalDistance = 0;
    let totalTime = 0;
    let segmentStart = pts[0];

    for (let i = 0; i < shardOrder.length; i++) {
      const shardName = shardOrder[i];
      const shardCfg = config.graphhopper.shards[shardName];
      const isLast = i === shardOrder.length - 1;
      const borderLat = isLast
        ? pts[pts.length - 1].lat
        : (isForward ? shardCfg.bbox.latMax : shardCfg.bbox.latMin);
      const segmentEnd = isLast
        ? pts[pts.length - 1]
        : computeBorderPoint(segmentStart, pts[pts.length - 1], borderLat);

      // GH request params
      const params = {
        ...baseParams,
        point: [`${segmentStart.lat},${segmentStart.lon}`, `${segmentEnd.lat},${segmentEnd.lon}`]
      };
      const resp = await ghAxios.get(shardCfg.url + '/route', { params });
      const path = resp.data.paths[0];
      const segmentCoords = decodePolyline(path.points);

      // Merge coordinates and instructions
      if (fullCoords.length) {
        fullCoords = concatenatePolylines(fullCoords, segmentCoords);
      } else {
        fullCoords = segmentCoords;
      }
      fullInstructions.push(...path.instructions);
      totalDistance += path.distance;
      totalTime += path.time;

      // Next start is last actual point
      segmentStart = segmentCoords[segmentCoords.length - 1];
    }

    // Respond with merged route
    res.json({ paths: [{
      points: encodePolyline(fullCoords),
      instructions: fullInstructions,
      distance: totalDistance,
      time: totalTime
    }] });
  } catch (err) {
    logger.error({ error: err.message, stack: err.stack, requestQuery: req.query }, 'Errore nel routing API');
    next(err);
  }
});

module.exports = router;
