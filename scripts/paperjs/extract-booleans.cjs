// Pinned fixture extraction; run with the path to paper@0.12.18 as argument.
// Paper executes setup/chained operations. Expected geometry is always taken
// from upstream assertions. Derived operands are explicitly marked.
const fs = require('node:fs');
const vm = require('node:vm');
const paper = require(process.argv[2]);
if (paper.version !== '0.12.18') throw Error('Requires paper 0.12.18');
paper.setup(new paper.Size(1000, 1000));
const provenance = new WeakMap(), fixtures = [], blocks = [];
let block, ordinal, depth = 0;
function geometry(item) {
  if (!item) return null;
  const paths = item instanceof paper.Path ? [item] : item.getItems({ class: paper.Path });
  return { fillRule: item.fillRule, subpaths: paths.map(path => ({
    closed: path.closed,
    start: path.firstSegment ? [path.firstSegment.point.x, path.firstSegment.point.y] : null,
    curves: path.curves.map(c => [0,2,4,6].flatMap(i => {
      const q = path.globalMatrix.transform(new paper.Point(c.values[i],c.values[i+1]));
      return [q.x,q.y];
    }))
  })) };
}
for (const op of ['unite','intersect','subtract','exclude','divide','resolveCrossings']) {
  const original = paper.PathItem.prototype[op];
  paper.PathItem.prototype[op] = function(other, options) {
    if (depth) return original.apply(this, arguments);
    const trace = { op, left: geometry(this), right: other instanceof paper.PathItem ? geometry(other) : null,
      options: options || null, derivedLeft: provenance.has(this), derivedRight: other ? provenance.has(other) : false };
    depth++;
    let result;
    try { result = original.apply(this, arguments); } finally { depth--; }
    provenance.set(result, trace);
    return result;
  };
}
const context = { paper, Point: paper.Point, Size: paper.Size, Path: paper.Path, PathItem: paper.PathItem,
 CompoundPath: paper.CompoundPath, Group: paper.Group, Rectangle: paper.Rectangle, project: paper.project,
 QUnit: {module(){}},
 test(title, callback) {
   block={id:blocks.length,title,comparisons:0,otherAssertions:0}; blocks.push(block);ordinal=0;
   paper.project.clear();
   try { callback(); } catch(e) { block.extractionError=String(e.stack); }
 },
 equals() { block.otherAssertions++; },
 compareBoolean(actual, expected, message) {
   actual = typeof actual === 'function' ? actual() : actual;
   const trace = provenance.get(actual);
   const expectedItem = typeof expected === 'string' ? paper.PathItem.create(expected) : expected;
   const expectedGeometry = geometry(expectedItem);
   if (typeof expected === 'string') expectedItem.remove();
   fixtures.push({ id:fixtures.length,block:block.id,title:block.title,ordinal:ordinal++,message:message??null,
     ...(trace || {op:null}), expected:expectedGeometry,expectedPathData:typeof expected === 'string'?expected:null });
   block.comparisons++;
 }
};
vm.runInNewContext(fs.readFileSync(__dirname+'/upstream/Path_Boolean.js','utf8'),context);
fs.writeFileSync(__dirname+'/booleans.json',JSON.stringify({runtime:paper.version,blocks,fixtures},null,2)+'\n');
console.log(JSON.stringify({blocks:blocks.length,fixtures:fixtures.length,errors:blocks.filter(b=>b.extractionError).map(b=>({title:b.title,error:b.extractionError})),untraced:fixtures.filter(f=>!f.op).map(f=>f.id)}));
