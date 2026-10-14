const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict');
const paper=require(process.argv[2]);assert.equal(paper.version,'0.12.18');paper.setup([1000,1000]);
const selected=new Set(['hit-testing a point that is extremely close to a curve','hit-testing the corner of a rectangle with miter stroke.','hit-testing fills with tolerance','hit-testing shapes with strokes and rounded corners (#1207)']);
const results=[];let row;
vm.runInNewContext(fs.readFileSync(__dirname+'/upstream/HitResult.js','utf8'),{
 paper,project:paper.project,Path:paper.Path,Shape:paper.Shape,Point:paper.Point,Size:paper.Size,
 QUnit:{module(){}},test(title,fn){if(selected.has(title)){paper.project.clear();row={title,assertions:0};fn();results.push(row);}},
 equals(actual,expected){if(typeof actual==='function')actual=actual();assert.equal(actual,expected);row.assertions++;},
 testHitResult(actual,expected){assert(actual);assert.equal(actual.type,expected.type);row.assertions++;}
});
assert.equal(results.length,4);
fs.writeFileSync(__dirname+'/extra-paper-fixture-validation.json',JSON.stringify({runtime:paper.version,results},null,2)+'\n');console.log(results);
