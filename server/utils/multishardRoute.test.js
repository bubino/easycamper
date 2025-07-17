// multishardRoute.test.js
// Funzione di routing multishard SOLO per test

const axios = require('axios');
const axiosRetry = require('axios-retry').default;
const qs = require('qs');
const config = require('../config/config');
const { decodePolyline, encodePolyline, concatenatePolylines } = require('../utils/polylineUtils');

const ghAxios = axios.create({
  paramsSerializer: params => qs.stringify(params, { arrayFormat: 'repeat' })
});
axiosRetry(ghAxios, { retries: 3 });

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

function computeBorderPoint(p1, p2, borderLat) {
  if (Math.abs(p2.lat - p1.lat) < 1e-7) {
    return { lat: borderLat, lon: p1.lon };
  }
  const t = (borderLat - p1.lat) / (p2.lat - p1.lat);
  return { lat: borderLat, lon: p1.lon + (p2.lon - p1.lon) * t };
}

function getOrderedShardNames(startShard, endShard) {
  const order = config.graphhopper.logicalOrder;
  const si = order.indexOf(startShard);
  const ei = order.indexOf(endShard);
  if (si < 0 || ei < 0) throw new Error(`Shard sconosciuto: ${startShard} o ${endShard}`);
  return si <= ei ? order.slice(si, ei + 1) : order.slice(ei, si + 1).reverse();
}

async function getMultiShardRouteTest({ start, end, profile = 'camper_eco', dimensions = {} }) {
  const pts = [start, end];
  const startShard = findShard(pts[0]);
  const endShard = findShard(pts[1]);
  if (!startShard || !endShard) {
    throw new Error('Punto fuori dall’area di copertura europea.');
  }
  const shardOrder = getOrderedShardNames(startShard, endShard);
  const logical = config.graphhopper.logicalOrder;
  const isForward = logical.indexOf(startShard) <= logical.indexOf(endShard);

  const baseParams = {
    profile,
    details: 'distance,time,instructions',
    points_encoded: true,
    ...(dimensions.height && { 'ch.max_height': dimensions.height }),
    ...(dimensions.width && { 'ch.max_width': dimensions.width }),
    ...(dimensions.length && { 'ch.max_length': dimensions.length }),
    ...(dimensions.weight && { 'ch.max_weight': dimensions.weight })
  };

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
      ? pts[1].lat
      : (isForward ? shardCfg.bbox.latMax : shardCfg.bbox.latMin);
    const segmentEnd = isLast
      ? pts[1]
      : computeBorderPoint(segmentStart, pts[1], borderLat);

    const params = {
      ...baseParams,
      point: [`${segmentStart.lat},${segmentStart.lon}`, `${segmentEnd.lat},${segmentEnd.lon}`]
    };
    const resp = await ghAxios.get(shardCfg.url + '/route', { params });
    const path = resp.data.paths[0];
    const segmentCoords = decodePolyline(path.points);

    if (fullCoords.length) {
      fullCoords = concatenatePolylines(fullCoords, segmentCoords);
    } else {
      fullCoords = segmentCoords;
    }
    fullInstructions.push(...path.instructions);
    totalDistance += path.distance;
    totalTime += path.time;
    segmentStart = segmentCoords[segmentCoords.length - 1];
  }

  return {
    points: encodePolyline(fullCoords),
    instructions: fullInstructions,
    distance: totalDistance,
    time: totalTime
  };
}

module.exports = { getMultiShardRouteTest };

test('dummy test', () => {
  expect(true).toBe(true);
});
