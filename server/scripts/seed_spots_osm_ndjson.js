'use strict';

// Import OSM-derived spots from an NDJSON file into Postgres.
//
// Usage:
//   node server/scripts/seed_spots_osm_ndjson.js --file /_dati_2/easycamper_seed/spots_seed.ndjson --batch 1000
//
// Notes:
// - Requires at least one user in DB (spots.userId is NOT NULL). We attach all seeded
//   rows to the first user found (can be changed later).
// - Uses stable IDs from NDJSON (e.g. "osm:n123").

const fs = require('fs');
const readline = require('readline');
const db = require('../models');

function parseArgs() {
  const args = process.argv.slice(2);
  const out = { file: null, batch: 1000 };
  for (let i = 0; i < args.length; i++) {
    const a = args[i];
    if (a === '--file') out.file = args[++i];
    else if (a === '--batch') out.batch = Number(args[++i]) || 1000;
  }
  return out;
}

function toSpotRow(userId, o) {
  const tags = (o.tags && typeof o.tags === 'object') ? { ...o.tags } : {};
  if (o.id) tags.osm_id = String(o.id);

  return {
    userId,
    name: String(o.name || ''),
    latitude: Number(o.latitude),
    longitude: Number(o.longitude),
    type: o.type || 'area_sosta',
    shortDescription: o.shortDescription || null,
    description: o.description || null,
    services: o.services && typeof o.services === 'object' ? o.services : null,
    tags: Object.keys(tags).length ? tags : null,
    // rating is community-driven
    ratingAverage: null,
    ratingCount: null,
  };
}

(async () => {
  const { file, batch } = parseArgs();
  if (!file) {
    console.error('Missing --file <path_to_ndjson>');
    process.exit(1);
  }
  if (!fs.existsSync(file)) {
    console.error(`File not found: ${file}`);
    process.exit(1);
  }

  try {
    await db.sequelize.authenticate();

    const user = await db.User.findOne();
    if (!user) {
      console.error('No users found. Create a user first, then run the seed.');
      process.exit(1);
    }

    const userId = user.id;

    async function upsertByNaturalKey(row) {
      // We can't use OSM ids as Spot.id because Spot.id is UUID.
      // Use a natural key to keep the seed idempotent.
      const where = {
        name: row.name,
        latitude: row.latitude,
        longitude: row.longitude,
        type: row.type,
      };

      const existing = await db.Spot.findOne({ where });
      if (existing) {
        await existing.update({
          shortDescription: row.shortDescription,
          description: row.description,
          services: row.services,
          tags: row.tags,
          userId: row.userId,
        });
        return;
      }

      await db.Spot.create(row);
    }

    const rl = readline.createInterface({
      input: fs.createReadStream(file, { encoding: 'utf8' }),
      crlfDelay: Infinity,
    });

    let buf = [];
    let total = 0;
    let skipped = 0;

    async function flush() {
      if (buf.length === 0) return;

      for (const row of buf) {
        try {
          await upsertByNaturalKey(row);
          total++;
        } catch (e) {
          skipped++;
        }
      }

      buf = [];
      process.stdout.write(`\rImported: ${total}  Skipped: ${skipped}`);
    }

    for await (const line of rl) {
      const trimmed = (line || '').trim();
      if (!trimmed) continue;
      let obj;
      try {
        obj = JSON.parse(trimmed);
      } catch (_) {
        skipped++;
        continue;
      }

      if (!obj || !obj.id || obj.latitude == null || obj.longitude == null) {
        skipped++;
        continue;
      }

      buf.push(toSpotRow(userId, obj));
      if (buf.length >= batch) {
        await flush();
      }
    }

    await flush();
    console.log(`\nDone. Imported: ${total}, skipped: ${skipped}`);
    process.exit(0);
  } catch (e) {
    console.error('\nSeed failed:', e);
    process.exit(1);
  }
})();
