const fs = require('node:fs'), vm = require('node:vm'), assert = require('node:assert/strict');
const paper = require(process.argv[2]);
assert.equal(paper.version, '0.12.18');
paper.setup([1000,1000]);
const title = 'Simplifying a path with three segments of the same position should not throw an error';
let input, output, assertions = [];
const geometry = path => ({closed:path.closed, nodes:path.segments.map(s=>s.point.toJSON()), curves:path.curves.map(c=>c.values)});
const original = paper.Path.prototype.simplify;
paper.Path.prototype.simplify = function(...args) {
  input = geometry(this);
  const result = original.apply(this,args);
  output = geometry(this);
  return result;
};
vm.runInNewContext(fs.readFileSync(__dirname+'/upstream/Path.js','utf8'), {
  Path:paper.Path, QUnit:{module(){}}, test(name,fn){if(name===title)fn();},
  equals(actual,expected){
    if(typeof actual==='function')actual=actual();
    assert.equal(actual,expected); assertions.push({actual,expected});
  }
});
assert.equal(assertions.length,1);
fs.writeFileSync(__dirname+'/path-coincident.json',JSON.stringify({runtime:paper.version,title,input,output,assertions},null,2)+'\n');
console.log(JSON.stringify({input,output,assertions}));
