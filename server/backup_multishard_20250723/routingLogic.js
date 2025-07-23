const axios = require('axios');
const qs = require('qs');
const { getShardForPoint } = require('./shardLocator');
const { BORDERS } = require('./borderPoints');

const NGINX_URL = 'http://localhost:3000';

// --- NUOVA FUNZIONE AUSILIARIA: Calcolo della distanza ---
function getDistance(p1, p2) {
    const R = 6371e3; // Metri
    const φ1 = p1.lat * Math.PI / 180;
    const φ2 = p2.lat * Math.PI / 180;
    const Δφ = (p2.lat - p1.lat) * Math.PI / 180;
    const Δλ = (p2.lon - p1.lon) * Math.PI / 180;

    const a = Math.sin(Δφ / 2) * Math.sin(Δφ / 2) +
              Math.cos(φ1) * Math.cos(φ2) *
              Math.sin(Δλ / 2) * Math.sin(Δλ / 2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    return R * c;
}

// --- FUNZIONE MIGLIORATA: Selezione intelligente del confine ---
function findClosestBorderPoint(startPoint, endPoint, borderPoints) {
    if (!borderPoints || borderPoints.length === 0) {
        throw { statusCode: 501, message: 'No border crossing defined for this route.' };
    }

    let bestPoint = null;
    let minDistance = Infinity;

    for (const borderPoint of borderPoints) {
        const distance = getDistance(startPoint, borderPoint) + getDistance(borderPoint, endPoint);
        if (distance < minDistance) {
            minDistance = distance;
            bestPoint = borderPoint;
        }
    }
    console.log(`Selected border point: ${bestPoint.name}`);
    return { lat: bestPoint.lat, lon: bestPoint.lon, name: bestPoint.name };
}

// --- Funzione per chiamare un singolo shard ---
async function fetchRouteFromShard(shardName, points, profile) {
    const url = `${NGINX_URL}/${shardName}/route`;
    const params = {
        point: points.map(p => `${p.lat},${p.lon}`),
        profile: profile,
        'points_encoded': false,
        'instructions': true,
        'calc_points': true,
    };

    try {
        const response = await axios.get(url, {
            params,
            paramsSerializer: p => qs.stringify(p, { arrayFormat: 'repeat' })
        });
        if (response.data.paths && response.data.paths.length > 0) {
            return response.data.paths[0];
        }
        throw new Error(`No path found in ${shardName}`);
    } catch (error) {
        const errorMsg = error.response ? JSON.stringify(error.response.data) : error.message;
        console.error(`Error fetching route from ${shardName}: ${errorMsg}`);
        throw { statusCode: 502, message: `Failed to get route from ${shardName}: ${errorMsg}` };
    }
}

// --- FUNZIONE DI CUCITURA DEFINITIVA ---
function stitchResponses(allPaths, legSegmentCounts) {
    if (!allPaths || allPaths.length === 0) return null;

    const finalPath = {
        distance: 0,
        time: 0,
        ascend: 0,
        descend: 0,
        points: { type: "LineString", coordinates: [] },
        instructions: [],
        legs: [],
        bbox: [Infinity, Infinity, -Infinity, -Infinity],
        snapped_waypoints: { type: "LineString", coordinates: [] }
    };

    let instructionOffset = 0;
    let pathCursor = 0;

    // Itera su ogni "leg" originale
    for (const segmentCount of legSegmentCounts) {
        let legDistance = 0;
        let legTime = 0;
        
        // Itera sui segmenti che compongono questa leg (1 se intra-shard, 2 se cross-shard)
        for (let i = 0; i < segmentCount; i++) {
            const path = allPaths[pathCursor];
            
            legDistance += path.distance;
            legTime += path.time;
            
            finalPath.distance += path.distance;
            finalPath.time += path.time;
            finalPath.ascend += path.ascend;
            finalPath.descend += path.descend;

            // Aggiungi punti, evitando duplicati al punto di giunzione
            const pointsToAdd = (pathCursor === 0) ? path.points.coordinates : path.points.coordinates.slice(1);
            finalPath.points.coordinates.push(...pointsToAdd);

            // Aggiungi istruzioni, ricalcolando gli indici e rimuovendo gli "Arrive" intermedi
            const instructionsToAdd = path.instructions.map(instr => ({
                ...instr,
                interval: [instr.interval[0] + instructionOffset, instr.interval[1] + instructionOffset]
            }));

            // Rimuovi l'ultima istruzione "Arrive" se non è l'ultimo segmento del percorso totale
            if (pathCursor < allPaths.length - 1) {
                instructionsToAdd.pop();
            }
            finalPath.instructions.push(...instructionsToAdd);
            instructionOffset += path.points.coordinates.length - 1;

            finalPath.bbox[0] = Math.min(finalPath.bbox[0], path.bbox[0]);
            finalPath.bbox[1] = Math.min(finalPath.bbox[1], path.bbox[1]);
            finalPath.bbox[2] = Math.max(finalPath.bbox[2], path.bbox[2]);
            finalPath.bbox[3] = Math.max(finalPath.bbox[3], path.bbox[3]);

            pathCursor++;
        }
        
        finalPath.legs.push({
            distance: legDistance,
            time: legTime,
            summary: `Route segment ${finalPath.legs.length + 1}`
        });
    }

    finalPath.snapped_waypoints.coordinates.push(
        allPaths[0].snapped_waypoints.coordinates[0],
        allPaths[allPaths.length - 1].snapped_waypoints.coordinates[1]
    );

    return {
        info: { copyrights: ["GraphHopper", "OpenStreetMap contributors"] },
        paths: [finalPath]
    };
}


// --- FUNZIONE PRINCIPALE DEFINITIVA ---
async function handleRouteRequest(points, profile) {
    if (points.length < 2) {
        throw { statusCode: 400, message: 'You must provide at least two points.' };
    }

    const tasks = [];
    const legSegmentCounts = [];

    // Itera su ogni tappa del viaggio (A->B, B->C, ...)
    for (let i = 0; i < points.length - 1; i++) {
        const startPoint = { lat: points[i][1], lon: points[i][0] };
        const endPoint = { lat: points[i+1][1], lon: points[i+1][0] };

        const startShard = getShardForPoint(startPoint.lat, startPoint.lon);
        const endShard = getShardForPoint(endPoint.lat, endPoint.lon);

        if (!startShard || !endShard) {
            throw { statusCode: 400, message: `Points for leg ${i+1} are outside of serviceable areas.` };
        }

        if (startShard === endShard) {
            console.log(`Leg ${i+1}: Intra-shard route in ${startShard}`);
            tasks.push(fetchRouteFromShard(startShard, [startPoint, endPoint], profile));
            legSegmentCounts.push(1); // Questa tappa è composta da 1 segmento
        } else {
            console.log(`Leg ${i+1}: Cross-shard route from ${startShard} to ${endShard}`);
            const borderKey = [startShard, endShard].sort().join('_');
            const borderPoints = BORDERS[borderKey];
            const borderPoint = findClosestBorderPoint(startPoint, endPoint, borderPoints);

            tasks.push(fetchRouteFromShard(startShard, [startPoint, borderPoint], profile));
            tasks.push(fetchRouteFromShard(endShard, [borderPoint, endPoint], profile));
            legSegmentCounts.push(2); // Questa tappa è composta da 2 segmenti
        }
    }

    console.log("Fetching all segments...");
    const allPaths = await Promise.all(tasks);

    console.log("Stitching all segments...");
    const finalResult = stitchResponses(allPaths, legSegmentCounts);
    return finalResult;
}

module.exports = { handleRouteRequest };