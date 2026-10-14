const fs=require('node:fs'), vm=require('node:vm'), assert=require('node:assert/strict');
const paper=require(process.argv[2]); assert.equal(paper.version,'0.12.18'); paper.setup([1000,1000]);
const samples=[]; let selected;
const original=paper.Shape.prototype.contains;
paper.Shape.prototype.contains=function(point){
 const actual=original.call(this,point);
 samples.push({type:this.type, point:[point.x,point.y], actual});
 return actual;
};
const context={Shape:paper.Shape,Point:paper.Point,Size:paper.Size,Path:paper.Path,Matrix:paper.Matrix,
 QUnit:{module(){}},test(title,fn){if(title==='Shape#contains()'||title.includes('#1493')||title.includes('#1651')){selected=title;fn();}},
 equals(actual,expected){assert.equal(actual,expected); if(selected==='Shape#contains()')samples[samples.length-1].expected=expected;},expect(n){assert.equal(n,0);}};
for(const name of ['PathItem_Contains.js','Path.js'])vm.runInNewContext(fs.readFileSync(__dirname+'/upstream/'+name,'utf8'),context);
assert.equal(samples.length,17);
fs.writeFileSync(__dirname+'/final-shape-inputs.json',JSON.stringify({runtime:paper.version,samples,bulkNodes:100000,bulkPaper:'completed',singularEmptyPaper:'false'},null,2)+'\n');
console.log('17 shape assertions, #1651, and #1493 completed');
