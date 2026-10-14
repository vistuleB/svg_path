const fs = require('node:fs'), vm = require('node:vm'), assert = require('node:assert/strict');
const paper = require(process.argv[2]);
assert.equal(paper.version, '0.12.18');
paper.setup([1000,1000]);
let input, assertions = [], queries = [];
const original = paper.Path.prototype.getOffsetsWithTangent;
paper.Path.prototype.getOffsetsWithTangent = function(...args) {
  input = {closed:this.closed, curves:this.curves.map(c=>c.values), length:this.length};
  const offsets = original.apply(this,args);
  queries.push({direction:args[0] || null, offsets,
    curveTimes: args.length ? this.curves.map(c=>c.getTimesWithTangent(args[0])) : null});
  return offsets;
};
vm.runInNewContext(fs.readFileSync(__dirname+'/upstream/Path.js','utf8'), {
  Path:paper.Path, Point:paper.Point, QUnit:{module(){}},
  test(title,fn){if(title==='Path#getOffsetsWithTangent()')fn();},
  equals(actual,expected,message){
    assert.deepEqual(JSON.parse(JSON.stringify(actual)),JSON.parse(JSON.stringify(expected)));
    assertions.push({actual,expected,message});
  }
});
assert.equal(assertions.length,3);
fs.writeFileSync(__dirname+'/path-tangents.json',JSON.stringify({runtime:paper.version,input,assertions,queries},null,2)+'\n');
console.log(queries);
