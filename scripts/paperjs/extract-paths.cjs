// Preserve inputs and literal assertions from pinned Path.js. Mutation results
// are never used as expected geometry. Paper executes upstream setup only.
const fs=require('node:fs'),vm=require('node:vm'),paper=require(process.argv[2]);
if(paper.version!=='0.12.18')throw Error('Requires paper 0.12.18');
paper.setup(new paper.Size(1000,1000));
let block=-1,current,depth=0;const blocks=[];
const selected=new Set([0,1,3,4,17,24,25,28,29,30]);
function geometry(p){return {closed:p.closed,curves:p.curves.map(c=>c.values.slice())};}
function wrap(proto,name){const original=proto[name];proto[name]=function(...args){
 const outer=depth++===0;
 const record=outer&&current?{method:name,left:geometry(this),args:args.map(a=>a instanceof paper.Path?geometry(a):a instanceof paper.CurveLocation?{offset:a.offset}:a)}:null;
 try{return original.apply(this,args);}finally{depth--;if(record)current.operations.push(record);}
};}
for(const method of ['join','reverse','flatten','splitAt'])wrap(paper.Path.prototype,method);
const time=paper.Curve.prototype.getTimeAt;
paper.Curve.prototype.getTimeAt=function(distance){
 if(block===0&&depth===0)current.operations.push({method:'getTimeAt',curve:this.values.slice(),distance});
 return time.apply(this,arguments);
};
for(const prop of ['length','area']) {
 const descriptor=Object.getOwnPropertyDescriptor(paper.Path.prototype,prop);
 Object.defineProperty(paper.Path.prototype,prop,{...descriptor,get(){
  if((block===0||block===1)&&depth===0)current.operations.push({method:prop,left:geometry(this)});
  return descriptor.get.call(this);
 }});
}
vm.runInNewContext(fs.readFileSync(__dirname+'/upstream/Path.js','utf8'),{
 paper,Path:paper.Path,Point:paper.Point,Size:paper.Size,Segment:paper.Segment,PathItem:paper.PathItem,
 QUnit:{module(){}},test(title,fn){block++;current={block,title,status:selected.has(block)?'extracted-subset':'pending',operations:[],assertions:[]};blocks.push(current);paper.project.clear();if(selected.has(block))fn();},
 equals(actual,expected,message,options){if(typeof actual==='function')actual();current.assertions.push({expected,message:message||null,options:options||null});},
 expect(count){current.expectedAssertionCount=count;}
});
fs.writeFileSync(__dirname+'/paths.json',JSON.stringify({blocks},null,2)+'\n');
console.log(blocks.filter(b=>b.status==='extracted-subset').map(b=>({block:b.block,operations:b.operations.length,assertions:b.assertions.length})));
