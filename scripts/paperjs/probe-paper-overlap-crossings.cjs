// Check runtime overlap flags separately from the pinned expected assertions.
// Usage: node scripts/paperjs/probe-paper-overlap-crossings.cjs /path/to/paper
const fs = require('node:fs');
const paper = require(process.argv[2]);
if (paper.version !== '0.12.18') throw Error('Requires paper 0.12.18');
paper.setup([1000, 1000]);
const fixture = JSON.parse(fs.readFileSync(__dirname + '/intersections.json'))[12];
function shape(g) {
  return new paper.Path({closed: g.closed, segments: g.curves.map((c, i) => {
    const previous = g.curves[(i + g.curves.length - 1) % g.curves.length];
    return new paper.Segment([c[0], c[1]],
      [previous[4] - c[0], previous[5] - c[1]], [c[2] - c[0], c[3] - c[1]]);
  })});
}
const results = shape(fixture.left).getIntersections(shape(fixture.right)).map(hit => ({
  point: [hit.point.x, hit.point.y], index: hit.index, time: hit.time,
  crossing: hit.isCrossing(), overlap: hit.hasOverlap(),
}));
fs.writeFileSync(__dirname + '/paper-overlap-crossing-reference.json',
  JSON.stringify({version: paper.version, fixture: 12, results}, null, 2) + '\n');
