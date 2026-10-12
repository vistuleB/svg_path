// Diagnostic screening, not a proof of region equivalence or a regression suite.
// Usage: node scripts/paperjs/probe-booleans.mjs /path/to/node_modules/paper [fixture-id]
import fs from 'node:fs';
import {Worker,isMainThread,parentPort,workerData} from 'node:worker_threads';
import {createRequire} from 'node:module';
const fixtures=JSON.parse(fs.readFileSync(new URL('./booleans.json',import.meta.url))).fixtures;
if(isMainThread){
 const selected=process.argv[3]===undefined?fixtures:fixtures.filter(f=>f.id===Number(process.argv[3]));
 const results=[];let next=0;
 const limitMs=Number(process.env.PAPER_AUDIT_TIMEOUT_MS??10000);
 async function run(){while(next<selected.length){
  const f=selected[next++],start=Date.now();
  const r=await new Promise(resolve=>{
   const w=new Worker(new URL(import.meta.url),{workerData:{fixture:f,paper:process.argv[2]}});
   let stage='startup';
   const timer=setTimeout(()=>{w.terminate();resolve({status:'timeout',limitMs,stage});},limitMs);
   w.on('message',r=>{if(r.progress){stage=r.progress;return;}clearTimeout(timer);w.terminate();resolve(r);});
   w.once('error',e=>{clearTimeout(timer);resolve({status:'harness-error',error:String(e.stack)});});
  });
  results.push({id:f.id,title:f.title,op:f.op,derivedOperands:!!(f.derivedLeft||f.derivedRight),elapsedMs:Date.now()-start,...r});
  if(results.length%20===0)console.log(`${results.length}/${selected.length} screened`);
 }}
 await Promise.all([run(),run()]);results.sort((a,b)=>a.id-b.id);
 const report={comparison:'Sampled bidirectional boundary distances and off-boundary fill classification, not exhaustive equivalence.',boundaryTolerance:0.001,results};
 fs.writeFileSync(new URL(process.argv[3]===undefined?'./boolean-screening.json':`./boolean-probe-${process.argv[3]}.json`,import.meta.url),JSON.stringify(report,null,2)+'\n');
 console.log(JSON.stringify(results.reduce((a,r)=>(a[r.status]=(a[r.status]??0)+1,a),{})));
}else{
 const f=workerData.fixture;
 const paper=createRequire(import.meta.url)(workerData.paper);
 if(paper.version!=='0.12.18')throw Error('Requires paper 0.12.18');
 paper.setup(new paper.Size(1000,1000));
 const s=await import('../../test_portable/build/dev/javascript/svg_path/svg_path.mjs');
 const csg=await import('../../test_portable/build/dev/javascript/svg_path/svg_path/csg.mjs');
 const serialize=await import('../../test_portable/build/dev/javascript/svg_path/svg_path/serialize.mjs');
 const {toList,Ok}=await import('../../test_portable/build/dev/javascript/svg_path/gleam.mjs');
 function path(g){
  if(!g)return s.path_empty();
  return s.path_combine(toList(g.subpaths.filter(p=>p.curves.length).map(p=>{
   let sub=s.subpath_assert(toList(p.curves.map(c=>new s.CubicBezier(...[0,2,4,6].map(i=>new s.Point(c[i],c[i+1]))))));
   if(p.closed)sub=s.subpath_assert_close(sub);
   return s.subpath_as_path(sub);
  })));
 }
 function paperPath(g){
  const paths=g.subpaths.filter(p=>p.curves.length).map(p=>{
   const curves=p.curves;
   const segments=curves.map((c,i)=>new paper.Segment([c[0],c[1]],i||p.closed?[curves[(i+curves.length-1)%curves.length][4]-c[0],curves[(i+curves.length-1)%curves.length][5]-c[1]]:[0,0],[c[2]-c[0],c[3]-c[1]]));
   if(!p.closed){const c=curves.at(-1);segments.push(new paper.Segment([c[6],c[7]],[c[4]-c[6],c[5]-c[7]],[0,0]));}
   return new paper.Path({segments,closed:p.closed,insert:false});
  });
  const result=new paper.CompoundPath({children:paths,insert:false});result.fillRule=g.fillRule??'nonzero';return result;
 }
 function clean(v){if(v&&typeof v==='object')return {type:v.constructor.name,...Object.fromEntries(Object.entries(v).map(([k,x])=>[k,clean(x)]))};return v;}
 let result;
 if(!f.op||f.options?.trace===false)result={status:'different-api',reason:'Open-path clipping / divided-result selection requires a separate adapter.'};
 else if(f.right&&f.left.fillRule!==f.right.fillRule)result={status:'different-api',reason:'Operands use different fill rules; Gleam binary CSG takes one common rule.'};
 else{
  const fn={unite:csg.union_path,intersect:csg.intersection_path,subtract:csg.difference_path,exclude:csg.symmetric_difference_path,resolveCrossings:csg.union_path}[f.op];
  parentPort.postMessage({progress:'csg'});
  const r=fn(path(f.left),path(f.right),f.left.fillRule==='evenodd'?new s.EvenOdd():new s.Nonzero());
  if(!(r instanceof Ok))result={status:'library-error',error:clean(r[0])};
  else{
   parentPort.postMessage({progress:'geometry-comparison'});
   const outputOptions=serialize.default_options();
   outputOptions.right_decimals=new serialize.System();
   outputOptions.use_s_t=false;outputOptions.use_h_v=false;
   const data=serialize.path_with(r[0],outputOptions);
   const actual=paper.PathItem.create(data);actual.fillRule='nonzero';
   const expected=paperPath(f.expected);
   const curves=p=>p instanceof paper.Path?p.curves:p.children.flatMap(q=>q.curves);
   const ac=curves(actual),ec=curves(expected);
   const nearest=(p,q)=>{const n=p.getNearestPoint(q);return n?n.getDistance(q):Infinity;};
   let maxBoundary=0,boundarySamples=0,fillSamples=0,mismatches=0,witness=null;
   for(const [from,to] of [[ac,expected],[ec,actual]])for(const c of from)for(const t of [0,.125,.25,.375,.5,.625,.75,.875,1]){
    const p=c.getPointAtTime(t),d=nearest(to,p);maxBoundary=Math.max(maxBoundary,d);boundarySamples++;
   }
   const box=actual.bounds.unite(expected.bounds);
   function check(p){if(nearest(actual,p)<=.001||nearest(expected,p)<=.001)return;
    fillSamples++;if(actual.contains(p)!==expected.contains(p)){mismatches++;witness??={x:p.x,y:p.y,actual:actual.contains(p),expected:expected.contains(p)};}}
   for(let i=0;i<25;i++)for(let j=0;j<25;j++)check(new paper.Point(box.x+box.width*(i+.37)/25,box.y+box.height*(j+.61)/25));
   for(const c of [...ac,...ec])for(const t of [.2,.5,.8]){const p=c.getPointAtTime(t),n=c.getNormalAtTime(t);if(n){check(p.add(n.multiply(.01)));check(p.subtract(n.multiply(.01)));}}
   result={status:maxBoundary<=.001&&!mismatches?'screen-match':'geometry-mismatch',maxBoundaryDistance:Number.isFinite(maxBoundary)?maxBoundary:'Infinity',boundarySamples,fillSamples,fillMismatches:mismatches,witness,outputPathData:data,outputCurves:ac.length,expectedCurves:ec.length};
  }
 }
 parentPort.postMessage(result);
}
