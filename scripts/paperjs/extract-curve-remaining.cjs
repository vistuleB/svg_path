// Preserve inputs and source assertions; numeric equality operands in relational
// tests can be Paper-computed and are labelled, not used as solver oracles.
const fs=require('node:fs'),vm=require('node:vm'),paper=require(process.argv[2]);
if(paper.version!=='0.12.18')throw Error('Requires paper 0.12.18');
paper.setup(new paper.Size(1000,1000));
let block=-1,current,depth=0;const blocks=[];
const selected=new Set([0,6,10,11,12,13,15,16]);
function value(x){if(x instanceof paper.Point)return [x.x,x.y];return x;}
for(const name of ['classify','isStraight','isLinear','getTimeAt','getLocationAt','getTimeOf','getLocationAtTime','divideAt','divideAtTime','getTimesWithTangent']){
 const original=paper.Curve.prototype[name];
 paper.Curve.prototype[name]=function(...args){const outer=depth++===0;const input=outer&&current?{method:name,curve:this.values.slice(),args:args.map(value)}:null;
  try{return original.apply(this,args);}finally{depth--;if(input)current.operations.push(input);}
 };
}
vm.runInNewContext(fs.readFileSync(__dirname+'/upstream/Curve.js','utf8'),{
 Path:paper.Path,Point:paper.Point,Curve:paper.Curve,QUnit:{module(){}},Numerical:{CURVETIME_EPSILON:1e-8},
 test(title,fn){block++;current={block,title,status:selected.has(block)?'extracted':'previous-batch',operations:[],assertions:[]};blocks.push(current);paper.project.clear();if(selected.has(block))fn();},
 equals(actual,expected,message,tolerance){if(typeof actual==='function')actual();current.assertions.push({expected:value(expected),message:message||null,tolerance:tolerance||null});}
});
fs.writeFileSync(__dirname+'/curve-remaining.json',JSON.stringify({blocks},null,2)+'\n');
console.log(blocks.filter(b=>b.status==='extracted').map(b=>({block:b.block,operations:b.operations.length,assertions:b.assertions.length})));
