// Dummy multishard route for test environment
function getMultiShardRouteTest(params) {
  return Promise.resolve({
    points: 'mocked_polyline',
    instructions: [],
    distance: 12345,
    time: 6789
  });
}

module.exports = { getMultiShardRouteTest };