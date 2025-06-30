const SHARD_BOUNDING_BOXES = {
    'europa-sud':      { minLat: 35.0, maxLat: 47.5, minLon: 5.0,  maxLon: 19.0 },
    'europa-centro':   { minLat: 47.0, maxLat: 55.5, minLon: 5.0,  maxLon: 24.0 },
    'europa-ovest':    { minLat: 36.0, maxLat: 51.5, minLon: -10.0, maxLon: 8.0  },
    'europa-nord':     { minLat: 54.0, maxLat: 71.0, minLon: 4.0,  maxLon: 32.0 },
    'europa-sud-est':  { minLat: 34.0, maxLat: 48.0, minLon: 19.0, maxLon: 42.0 },
};

function getShardForPoint(lat, lon) {
    for (const shardName in SHARD_BOUNDING_BOXES) {
        const box = SHARD_BOUNDING_BOXES[shardName];
        if (lat >= box.minLat && lat <= box.maxLat && lon >= box.minLon && lon <= box.maxLon) {
            return shardName;
        }
    }
    return null;
}

module.exports = { getShardForPoint };