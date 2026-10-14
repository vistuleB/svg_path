// Execute the six original arc-construction blocks against the pinned runtime.
const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const paper = require(process.argv[2]);
assert.equal(paper.version, '0.12.18');
paper.setup([1000, 1000]);
const cases = [];
let current;
const original = paper.Path.prototype.arcTo;
paper.Path.prototype.arcTo = function(...args) {
  current.arguments = args.map(v => v && v.toJSON ? v.toJSON() : v);
  current.start = this.lastSegment.point.toJSON();
  try { return original.apply(this, args); }
  catch (error) { current.error = error.message; throw error; }
  finally {
    current.result = {closed: this.closed, nodes: this.segments.map(s => s.point.toJSON()), curves: this.curves.map(c => c.values)};
  }
};
vm.runInNewContext(fs.readFileSync(__dirname + '/upstream/Path.js', 'utf8'), {
  Path: paper.Path, Point: paper.Point, Size: paper.Size,
  QUnit: {module() {}},
  test(title, fn) {
    if (!title.startsWith('Path#arcTo(')) return;
    current = {title, assertions: []};
    fn();
    cases.push(current);
  },
  equals(actual, expected, message) {
    assert.deepEqual(actual, expected);
    current.assertions.push({actual, expected, message});
  },
  expect(count) { current.expectedAssertionCount = count; }
});
assert.equal(cases.length, 6);
fs.writeFileSync(__dirname + '/path-arcs.json', JSON.stringify({runtime: paper.version, cases}, null, 2) + '\n');
console.log('6 original arc-construction blocks passed');
