// Execute the pinned tests without editing their source. Capture mode wraps only
// outermost selected geometry calls; baseline mode installs no wrappers.
const fs = require('node:fs');
const path = require('node:path');
const {createRequire} = require('node:module');
const root = __dirname;
const source = path.join(root, 'upstream');
const req = createRequire(path.join(source, 'package.json'));
process.chdir(source);
req('@babel/register')({extensions:['.js'], ignore:[/node_modules/]});
const Mocha = req('mocha');
const mode = process.argv[2] || 'baseline';
if (!['baseline','arc-circle','arc-extra','linear','primitives','polygons','chains','residual'].includes(mode)) throw Error('Unknown batch');
function files(dir) { return fs.readdirSync(dir,{withFileTypes:true}).flatMap(e => e.isDirectory()?files(path.join(dir,e.name)):[path.join(dir,e.name)]); }
const selected = mode==='baseline' ? files(path.join(source,'test')).filter(f=>f.endsWith('.js')).sort()
 : mode==='residual'?['test/algorithms/relation.js','test/data_structures/planar_set.js','test/data_structures/linked_list.js'].map(f=>path.join(source,f))
 : mode==='polygons'?['test/classes/polygon.js','test/algorithms/ray_shooting.js','test/algorithms/boolean_op.js'].map(f=>path.join(source,f))
 : (mode==='chains'?['face','multiline']:mode==='primitives'?['point','vector','matrix','box']:mode==='linear'?['segment','line','ray']:['arc','circle']).map(f=>path.join(source,`test/classes/${f}.js`));
const calls = [];
let active = null, depth = 0;
function plain(value) {
 if(value==null || typeof value!=='object') return value;
 if(Array.isArray(value)) return value.map(plain);
 switch(value.name) {
 case 'point': case 'vector': return {type:value.name,x:value.x,y:value.y};
 case 'segment': return {type:'segment',start:plain(value.start),end:plain(value.end)};
 case 'arc': return {type:'arc',center:plain(value.pc),radius:value.r,startAngle:value.startAngle,endAngle:value.endAngle,ccw:value.counterClockwise,sweep:value.sweep,start:plain(value.start),end:plain(value.end)};
 case 'circle': return {type:'circle',center:plain(value.pc),radius:value.r};
 case 'ray': case 'line': return {type:value.name,point:plain(value.pt),normal:plain(value.norm)};
 case 'box': return {type:'box',xmin:value.xmin,ymin:value.ymin,xmax:value.xmax,ymax:value.ymax};
 default:
  if(value.constructor.name==='PlanarSet') return {type:'planarset',shapes:[...value].map(plain)};
  if(value.constructor.name==='DE9IM') return {type:'de9im',matrix:value.m.map(plain)};
  if(['Face','Multiline'].includes(value.constructor.name)) return {type:value.constructor.name.toLowerCase(),edges:[...value.edges].map(e=>plain(e.shape))};
  if(value.constructor.name==='Matrix') return {type:'matrix',a:value.a,b:value.b,c:value.c,d:value.d,tx:value.tx,ty:value.ty};
  if(value.constructor.name==='Polygon') return {type:'polygon',edges:[...value.edges].map(e=>plain(e.shape)),faces:[...value.faces].map(f=>[...f].map(e=>plain(e.shape)))};
  return {type:value.name || value.constructor.name};
 }
}
if(mode!=='baseline') {
 const F=req('./index.js');
 for(const name of (mode==='residual'?['Polygon']:mode==='chains'?['Face','Multiline','Point']:mode==='polygons'?['Polygon','Circle','Segment']:mode==='primitives'?['Point','Vector','Matrix','Box','Segment']:mode==='linear'?['Segment','Line','Ray']:['Arc','Circle'])) {
  const proto=F[name].prototype;
  for(const operation of (mode==='residual'?['contains','distanceTo']:mode==='chains'?['signedArea','area','orientation','pointAtLength','length','perimeter','box','distanceTo']:mode==='polygons'?['area','box','contains','distanceTo','intersect','translate','rotate','transform']:mode==='primitives'?['translate','rotate','scale','transform','multiply','dot','cross','length','slope','normalize','add','subtract','invert','angleTo','projectionOn','distanceTo','on','leftTo','contains','merge','intersect']:mode==='arc-extra'?['middle','tangentInStart','tangentInEnd','reverse','transform','definiteIntegral','breakToFunctional']:['intersect','distanceTo','contains','pointAtLength','length','box',...(mode==='linear'?['middle','tangentInStart','tangentInEnd','translate','rotate']:[])])) {
   let owner=proto;
   while(owner && !Object.hasOwn(owner,operation)) owner=Object.getPrototypeOf(owner);
   const desc=owner && Object.getOwnPropertyDescriptor(owner,operation);
   if(!desc) continue;
   const original=desc.value || desc.get;
   function wrapped(...args) {
    if(!active || depth) return original.apply(this,args);
    depth++;
    try {
     const input=plain(this),arguments_=args.map(plain);
     let result;
     try {result=original.apply(this,args);} catch(e) {
      calls.push({...active,operation,input,arguments:arguments_,thrown:String(e)});
      throw e;
     }
     calls.push({...active,operation,input,arguments:arguments_,result:plain(result)});
     return result;
    } finally {depth--;}
   }
   Object.defineProperty(proto,operation,desc.get?{...desc,get:wrapped}:{...desc,value:wrapped});
  }
 }
}
if(['polygons','residual'].includes(mode)) {
 for(const [module,names] of [['./src/algorithms/boolean_op.js',['unify','subtract','intersect','innerClip','outerClip','calculateIntersections']],['./src/algorithms/ray_shooting.js',['ray_shoot']],...(mode==='residual'?[['./src/algorithms/relation.js',['relate','disjoint','equal','intersect','touch','inside','contain','covered','cover']],['./src/algorithms/distance.js',['shape2planarSet']]]:[])]) {
  const exports=module.endsWith('/distance.js')?req(module).Distance:req(module);
  const prefix=module.endsWith('/relation.js')?'relation':'algorithm';
  for(const name of names) {
   const original=exports[name];
   exports[name]=function(...args) {
    if(!active||depth) return original.apply(exports,args);
    depth++;
    try {
     const input=plain(args[0]),arguments_=args.slice(1).map(plain);
     let result;
     try {result=original.apply(exports,args);} catch(e) {
      calls.push({...active,operation:`${prefix}:${name}`,input,arguments:arguments_,thrown:String(e)});throw e;
     }
     calls.push({...active,operation:`${prefix}:${name}`,input,arguments:arguments_,result:plain(result)});
     return result;
    } finally {depth--;}
   };
  }
 }
}

const mocha = new Mocha({reporter:'dot',timeout:10000});
selected.forEach(f=>mocha.addFile(f));
const results=[];
const runner=mocha.run(failures=>{process.exitCode=failures?1:0;});
const fileOrdinals=new Map();
runner.on('test',t=>{const file=path.relative(source,t.file);const ordinal=(fileOrdinals.get(file)??0)+1;fileOrdinals.set(file,ordinal);active={file,test:t.fullTitle(),testOrdinal:ordinal};});
runner.on('test end',t=>{results.push({file:path.relative(source,t.file),test:t.fullTitle(),testOrdinal:active?.testOrdinal,state:t.state,duration:t.duration,error:t.err?.message});active=null;});
runner.on('pending',t=>results.push({file:path.relative(source,t.file),test:t.fullTitle(),state:'pending'}));
runner.on('end',()=>{
 fs.writeFileSync(path.join(root,`upstream-${mode}.json`),JSON.stringify({stats:runner.stats,files:selected.map(f=>path.relative(source,f)),tests:results},null,2)+'\n');
 if(mode!=='baseline') fs.writeFileSync(path.join(root,`${mode}-calls.jsonl`),calls.map(c=>JSON.stringify(c,(_key,v)=>typeof v==='number'&&!Number.isFinite(v)?String(v):v)).join('\n')+'\n');
 console.log(`Recorded ${results.length} tests${mode!=='baseline'?` and ${calls.length} calls`:''}.`);
});
