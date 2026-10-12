// Extract explicit assertions from the pinned upstream Curve.js.
// Paper executes construction and length-derived input setup, not expectations.
const fs = require('node:fs');
const vm = require('node:vm');
const paper = require(process.argv[2]);
if (paper.version !== '0.12.18') throw Error('Requires paper 0.12.18');
paper.setup(new paper.Size(1000, 1000));
const methods = ['getPointAtTime', 'getTangentAtTime', 'getWeightedTangentAtTime',
  'getNormalAtTime', 'getWeightedNormalAtTime', 'getCurvatureAtTime',
  'getTimeAt', 'getPartLength'];
let last, depth = 0, block = -1, title;
const fixtures = [], blocks = [];
const selected = new Set([1,2,3,4,5,7,8,9,14]);
for (const method of methods) {
  const original = paper.Curve.prototype[method];
  paper.Curve.prototype[method] = function(...args) {
    const outer = depth++ === 0;
    try { return original.apply(this,args); }
    finally {
      depth--;
      if (outer) last = {method, curve: this.values.slice(), args};
    }
  };
}
const staticTime = paper.Curve.getTimeAt;
paper.Curve.getTimeAt = function(values,...args) {
  const outer = depth++ === 0;
  try { return staticTime.call(this,values,...args); }
  finally { depth--; if (outer) last = {method:'getTimeAt',curve:values.slice(),args}; }
};
vm.runInNewContext(fs.readFileSync(__dirname+'/upstream/Curve.js','utf8'), {
  Curve:paper.Curve, Path:paper.Path, Point:paper.Point, QUnit:{module(){}},
  test(name,callback) {
    block++; title=name; last=null; paper.project.clear();
    blocks.push({block,title,status:selected.has(block)?'extracted-subset':'pending'});
    if(selected.has(block)) callback();
  },
  equals(actual,expected,message) {
    if(typeof actual==='function') { last=null; actual=actual(); }
    const call=last; last=null;
    if(!call || String(message).startsWith('Legacy:')) return;
    // Out-of-range getPointAt is an arc-length API, outside this extraction.
    if(expected===null) return;
    const component = /Point at t=/.test(message||'') ? 'y' : null;
    fixtures.push({id:fixtures.length,block,title,...call,component,
      expected:expected instanceof paper.Point?[expected.x,expected.y]:expected,
      message:message||null});
  }
});
fs.writeFileSync(__dirname+'/curves.json',JSON.stringify({blocks,fixtures},null,2)+'\n');
console.log(`Extracted ${fixtures.length} comparisons from ${selected.size} of ${blocks.length} blocks`);
