const fs=require('node:fs'),vm=require('node:vm'),paper=require(process.argv[2]);
if(paper.version!=='0.12.18')throw Error('Requires paper 0.12.18');
let block=-1,title,last,depth=0;const fixtures=[],blocks=[];
for(const method of ['solveQuadratic','solveCubic']){const original=paper.Numerical[method];paper.Numerical[method]=function(...args){const outer=depth++===0;try{return original.apply(this,args);}finally{depth--;if(outer)last={method,coefficients:args.slice(0,method==='solveQuadratic'?3:4)};}};}
vm.runInNewContext(fs.readFileSync(__dirname+'/upstream/Numerical.js','utf8'),{Numerical:paper.Numerical,QUnit:{module(){}},test(name,fn){block++;title=name;blocks.push({block,title});fn();},equals(actual,expected,message){fixtures.push({id:fixtures.length,block,title,...last,expected,actual,message});}});
fs.writeFileSync(__dirname+'/numerical.json',JSON.stringify({epsilon:paper.Numerical.EPSILON,blocks,fixtures},null,2)+'\n');
