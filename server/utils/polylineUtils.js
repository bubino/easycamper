const polyline = require('@mapbox/polyline');

/** Decode encoded polyline string to array of [lat, lon] pairs */
function decodePolyline(encoded) {
  if (!encoded) return [];
  return polyline.decode(encoded);
}

/** Encode array of [lat, lon] pairs to encoded polyline string */
function encodePolyline(coordinates) {
  if (!coordinates || !coordinates.length) return '';
  return polyline.encode(coordinates);
}

/** Concatenate two coordinate segments, removing duplicate junction point */
function concatenatePolylines(segment1, segment2) {
  if (!segment1 || !segment1.length) return segment2;
  if (!segment2 || !segment2.length) return segment1;
  const last1 = segment1[segment1.length - 1];
  const first2 = segment2[0];
  const tol = 1e-7;
  const isDup = Math.abs(last1[0] - first2[0]) < tol && Math.abs(last1[1] - first2[1]) < tol;
  return isDup ? segment1.concat(segment2.slice(1)) : segment1.concat(segment2);
}

module.exports = {
  decodePolyline,
  encodePolyline,
  concatenatePolylines
};