// Run: node scripts/paperjs/extract-intersections.cjs /path/to/node_modules/paper
// Extraction only: expected results come from upstream assertions, never from
// executing Paper.js's intersection solver.
const fs = require('node:fs');
const vm = require('node:vm');
const paper = require(process.argv[2]);
if (paper.version !== '0.12.18') throw Error('Extraction requires paper 0.12.18');
paper.setup(new paper.Size(1000, 1000));
let title, ordinal;
const fixtures = [];
function geometry(item) {
  if (item instanceof paper.Curve) return { closed: false, curves: [item.values] };
  const matrix = item.globalMatrix;
  return { closed: item.closed, curves: item.curves.map(c => {
    const values = c.values;
    return [0, 2, 4, 6].flatMap(i => {
      const p = matrix.transform(new paper.Point(values[i], values[i + 1]));
      return [p.x, p.y];
    });
  }) };
}
for (const prototype of [paper.PathItem.prototype, paper.Curve.prototype]) {
  for (const method of ['getIntersections', 'getCrossings']) {
    prototype[method] = function(other) {
      return { method, left: geometry(this), right: other ? geometry(other) : null,
        expectedMatrix: this instanceof paper.Curve ? new paper.Matrix() : this.globalMatrix.clone() };
    };
  }
}
let source = fs.readFileSync(__dirname + '/upstream/Path_Intersections.js', 'utf8');
source = source.replace(/function testIntersections\(intersections, results\) \{[\s\S]*?\n\}\n/, '');
const context = { ...paper, Point: paper.Point, Size: paper.Size, Path: paper.Path,
  Curve: paper.Curve, Shape: paper.Shape, project: paper.project,
  QUnit: { module() {} }, equals() {},
  test(name, callback) { title = name; ordinal = 0; paper.project.clear(); callback(); },
  testIntersections(input, expected) {
    const { expectedMatrix, ...geometryInput } = input;
    fixtures.push({ title, ordinal: ordinal++, ...geometryInput,
      expected: expected.map(e => {
        const p = e.point ? expectedMatrix.transform(new paper.Point(e.point)) : null;
        return { ...e, point: p ? [p.x, p.y] : null };
      }) });
  }
};
// intersects() is an object-level convenience assertion, outside this extraction.
paper.Item.prototype.intersects = () => true;
vm.runInNewContext(source, context);
fs.writeFileSync(__dirname + '/intersections.json', JSON.stringify(fixtures, null, 2) + '\n');
console.log(`Extracted ${fixtures.length} assertions from ${new Set(fixtures.map(f => f.title)).size} upstream blocks`);
