// Inventory source assertions. Gleam has no public affine decomposition query.
const fs=require('node:fs'),vm=require('node:vm'),paper=require(process.argv[2]);
if(paper.version!=='0.12.18')throw Error('Requires paper 0.12.18');
let last,block=-1,title;const blocks=[],fixtures=[];
for(const method of ['getRotation','getScaling']){const original=paper.Matrix.prototype[method];paper.Matrix.prototype[method]=function(...args){const actual=original.apply(this,args);last={method,matrix:this.values.slice()};return actual;};}
vm.runInNewContext(fs.readFileSync(__dirname+'/upstream/Matrix.js','utf8'),{Matrix:paper.Matrix,Point:paper.Point,Base:{pick:(a,b)=>a===undefined?b:a},QUnit:{module(){}},test(name,fn){block++;title=name;blocks.push({block,title,status:'no-public-decomposition-counterpart'});fn();},equals(actual,expected,message){fixtures.push({id:fixtures.length,block,title,...last,expected:expected instanceof paper.Point?[expected.x,expected.y]:expected,actual:actual instanceof paper.Point?[actual.x,actual.y]:actual,message});}});
fs.writeFileSync(__dirname+'/matrix.json',JSON.stringify({blocks,fixtures},null,2)+'\n');console.log(`${fixtures.length} matrix decomposition assertions preserved; no Gleam comparison claimed`);
