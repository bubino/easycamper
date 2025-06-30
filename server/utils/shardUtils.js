function findShard(lat, lon) {
  for (const shardName in shardConfig) {
    const shard = shardConfig[shardName];
    const { bbox } = shard;
    if (lat >= bbox.latMin && lat <= bbox.latMax && lon >= bbox.lonMin && lon <= bbox.lonMax) {
      return shard;
    }
  }
  return null;
}

function pointToShard(lat, lon) {
  const shard = findShard(lat, lon);
  return shard ? shard.name : null;
}