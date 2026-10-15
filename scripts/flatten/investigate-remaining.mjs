// Replays the deferred queue without overwriting the original audit observations.
import fs from 'node:fs';
import {Worker,isMainThread,parentPort,workerData} from 'node:worker_threads';
import {execFileSync} from 'node:child_process';
process.env.FLATTEN_LIBRARY_ONLY='1';
const {compare,pieces,polygonPath,errorDetails}=await import('./compare-arc-circle.mjs');
const base=process.env.PROBE_RUNTIME??'../../test_portable/build/dev/javascript/';
const g=await import(base+'svg_path/svg_path.mjs');
const arr=await import(base+'svg_path/svg_path/arrangement.mjs');
const ix=await import(base+'svg_path/svg_path/intersections.mjs');
const overlaps=await import(base+'svg_path/svg_path/overlaps.mjs');
const csg=await import(base+'svg_path/svg_path/csg.mjs');
const area=await import(base+'svg_path/svg_path/area.mjs');
const ct=await import(base+'svg_path/svg_path/containment.mjs');
const distance=await import(base+'svg_path/svg_path/distance.mjs');
const {toList}=await import(base+'prelude.mjs');
const calls=fs.readFileSync(new URL('polygons-calls.jsonl',import.meta.url),'utf8').trim().split('\n').map(JSON.parse);
const simple=r=>r.isOk()?{ok:true}:errorDetails(r[0]);
const unwrap=r=>{if(!r.isOk())throw r[0];return r[0];};
const execute=({id,mode='replay',tolerance=1e-6,scale=1,i,j})=>{
 const c=structuredClone(calls[id-1]);
 if(mode==='replay')return compare(c);
 if(mode==='distance-pairs'){const a=pieces(c.input)[i],b=pieces(c.arguments[0])[j];const r=distance.segment_segment_closest_pair(a,b);return r.isOk()?{distance:r[0].distance,left:a,right:b}:simple(r);}
 if(mode==='distance-reduced'){
  const a=new g.Line(new g.Point(170,200),new g.Point(120,350));
  const b=new g.Arc(new g.Point(200,300),new g.Point(50,50),0,false,true,new g.Point(250,250));
  const options=Object.assign(ix.default_options(),{max_depth:Number(process.env.PROBE_DEPTH??48)});
  const r=distance.segment_segment_closest_pair_with(a,b,options);
  return {query:simple(r),distance:r.isOk()?r[0].distance:null,analytic:Math.hypot(102,34)-50,depth:options.max_depth};
 }
 if(mode==='distance-arc-reduced'){
  const a=new g.Arc(new g.Point(205,150),new g.Point(30,30),0,false,true,new g.Point(175,180));
  const b=new g.Arc(new g.Point(200,300),new g.Point(50,50),0,false,true,new g.Point(250,250));
  const r=distance.segment_segment_closest_pair(a,b);
  return {query:simple(r),distance:r.isOk()?r[0].distance:null,analytic:Math.hypot(75,150)-80,searchWindows:globalThis.flattenWindows??null};
 }
 if(mode==='overlap-reduced'){
  const a=new g.Line(new g.Point(1336017144.7222269,514632.0777871349),new g.Point(1336017149.883367,514641.78073088516));
  const b=new g.Line(new g.Point(1336017144.722227,514632.077786993),new g.Point(1336017149.8833673,514641.780730718));
  return {left:a,right:b,tolerance:5e-7,intersections:simple(ix.segment_with(a,b,Object.assign(ix.default_options(),{tolerance:5e-7}))),overlaps:errorDetails(overlaps.segment_with(a,b,5e-7))};
 }
 if(mode==='gaps'){
  return ['input','argument','result'].map(label=>{
   const shape=label==='input'?c.input:label==='argument'?c.arguments[0]:c.result;
   if(shape.type!=='polygon')return {label};
   const gaps=shape.faces.flatMap((f,face)=>f.flatMap((s,i)=>{
    const a=s.end,b=f[(i+1)%f.length].start,d=Math.hypot(a.x-b.x,a.y-b.y);
    return d?[{face,edge:i,gap:d,end:a,next:b}]:[];
   }));
   let adapted;try{polygonPath(shape);adapted={ok:true};}catch(e){adapted=errorDetails(e);}
   return {label,gaps,adapted};
  });
 }
 const segs=[...pieces(c.input),...pieces(c.arguments[0])].map(s=>new g.Line(new g.Point(s.start.x*scale,s.start.y*scale),new g.Point(s.end.x*scale,s.end.y*scale)));
 if(mode==='arrangement'||mode==='source-balance'||mode==='graph-snapshot'){
  const build=arr.build_with(toList(segs),tolerance,Number(process.env.PROBE_MINIMUM??1e-5)*scale,0);
  if(!build.isOk())return {stage:'build',error:simple(build)};
  const b=build[0];
  if(mode==='graph-snapshot')return {vertices:[...b.graph.vertices].map(v=>({id:v.id,point:v.point,samples:[...v.endpoint_samples]})),edges:[...b.graph.edges],orders:[...b.graph.cyclic_orders].map(([id,groups])=>({id,groups:[...groups].map(group=>[...group])}))};
  if(mode==='source-balance'){
   const edges=new Map([...b.graph.edges].map(e=>[e.id,e]));
   const vertices=new Map([...b.graph.vertices].map(v=>[v.id,v]));
   const balances=[true,false].map(left=>{
    const flux=new Map();
    for(const image of b.edge_images){
     const edge=edges.get(image.edge_id);
     const weight=[...image.sources].reduce((n,s)=>n+(((s.segment_index<pieces(c.input).length)===left)?(s.reversed?-1:1):0),0);
     flux.set(edge.start_vertex,(flux.get(edge.start_vertex)??0)-weight);
     flux.set(edge.end_vertex,(flux.get(edge.end_vertex)??0)+weight);
    }
    return [...flux].filter(([id,flow])=>flow!==0).map(([id,flow])=>({id,flow,vertex:vertices.get(id),incident:[...edges.values()].filter(e=>e.start_vertex===id||e.end_vertex===id).map(e=>({edge:e,image:[...b.edge_images].find(i=>i.edge_id===e.id)}))}));
   });
   const unseen=new Set(vertices.keys());let components=0;
   while(unseen.size){components++;const todo=[unseen.values().next().value];while(todo.length){const id=todo.pop();if(!unseen.delete(id))continue;for(const edge of edges.values()){if(edge.start_vertex===id)todo.push(edge.end_vertex);if(edge.end_vertex===id)todo.push(edge.start_vertex);}}}
   const dual=arr.dual(b.graph);
   return {balances,vertices:vertices.size,edges:edges.size,components,planarEulerFaceCount:edges.size-vertices.size+1+components,dualFaces:dual.isOk()?[...dual[0].faces].length:null};
  }
  const dual=arr.dual(b.graph);
  if(!dual.isOk())return {stage:'dual',error:simple(dual),vertices:[...b.graph.vertices].length,edges:[...b.graph.edges].length};
  const winds=[true,false].map(left=>{
   const changes=[...b.edge_images].map(image=>new arr.EdgeWindingChange(image.edge_id,[...image.sources].reduce((n,source)=>n+(((source.segment_index<pieces(c.input).length)===left)?(source.reversed?-1:1):0),0)));
   return simple(arr.face_windings(dual[0],toList(changes)));
  });
  return {stage:'windings',winds,vertices:[...b.graph.vertices].length,edges:[...b.graph.edges].length,faces:[...dual[0].faces].length};
 }
 if(mode==='prefix'){
  let previous=null;
  for(let n=1;n<=segs.length;n++){
   const r=arr.build_with(toList(segs.slice(0,n)),tolerance,Number(process.env.PROBE_MINIMUM??1e-5)*scale,0);
   if(!r.isOk()){
    const pairs=previous?[...previous.graph.edges].map(edge=>({edge:edge.id,segment:edge.segment,result:ix.segment_with(edge.segment,segs[n-1],Object.assign(ix.default_options(),{tolerance}))})).filter(x=>!x.result.isOk()&&x.result[0].constructor.name!=='OverlappingSegments').map(x=>({...x,result:simple(x.result)})):[];
    return {n,error:simple(r),inserted:segs[n-1],pairs};
   }
   previous=r[0];
  }
  return {ok:true};
 }
 if(mode==='pairs'){
  const bad=[];
  for(let i=0;i<segs.length;i++)for(let j=i+1;j<segs.length;j++){
   const r=ix.segment_with(segs[i],segs[j],Object.assign(ix.default_options(),{tolerance}));
   if(!r.isOk() && r[0].constructor.name!=='OverlappingSegments')bad.push({i,j,left:segs[i],right:segs[j],error:errorDetails(r[0]),overlaps:simple(overlaps.segment_with(segs[i],segs[j],tolerance))});
  }
  return bad;
 }
 if(mode==='boolean'){
  const n=pieces(c.input).length;
  const paths=[new g.Path(toList([unwrap(g.subpath(toList(segs.slice(0,n))))])),new g.Path(toList([unwrap(g.subpath(toList(segs.slice(n))))]))];
  const fn={'algorithm:unify':csg.union_path_with,'algorithm:subtract':csg.difference_path_with,'algorithm:intersect':csg.intersection_path_with}[c.operation];
  const r=fn(...paths,new g.EvenOdd(),new csg.Options(tolerance,Number(process.env.PROBE_MINIMUM??1e-5)*scale));
  return r.isOk()?{ok:true,area:area.signed_path(r[0]),segments:[...r[0].subpaths].flatMap(s=>[...s.segments]).length}:simple(r);
 }
 if(mode==='rectangle'){
  const left=polygonPath(c.input),right=polygonPath(c.arguments[0]),expected=polygonPath(c.result);
  const actual=unwrap(csg.difference_path(left,right,new g.EvenOdd()));
  const samples=[new g.Point(50,100),new g.Point(150,100)].map(p=>({point:p,left:simple(ct.path_containment(p,left,new g.EvenOdd())),ours:unwrap(ct.path_containment(p,actual,new g.EvenOdd())).constructor.name,upstream:unwrap(ct.path_containment(p,expected,new g.EvenOdd())).constructor.name}));
  return {actual:errorDetails(actual),samples};
 }
 throw Error('Unknown mode');
};
if(!isMainThread){try{const t=performance.now();parentPort.postMessage({result:execute(workerData),ms:performance.now()-t});}catch(e){parentPort.postMessage({error:errorDetails(e),stack:e.stack});}}
else {
 const mode=process.argv[2]??'replay';
 const ids=process.argv.slice(3).map(Number);
 const selected=ids.length?ids:JSON.parse(fs.readFileSync(new URL('discrepancy-queue.json',import.meta.url))).filter(x=>x.id.startsWith('polygons:')).map(x=>Number(x.id.split(':')[1]));
 const jobs=mode==='distance-pairs'?selected.flatMap(id=>pieces(calls[id-1].input).flatMap((a,i)=>pieces(calls[id-1].arguments[0]).map((b,j)=>({id,mode,i,j})))):selected.map(id=>({id,mode,tolerance:Number(process.env.PROBE_TOLERANCE??1e-6),scale:Number(process.env.PROBE_SCALE??1)}));
 const rows=[];let cursor=0;
 async function lane(){while(cursor<jobs.length){const job=jobs[cursor++];const response=await new Promise(resolve=>{
  const w=new Worker(new URL(import.meta.url),{workerData:job});
  const timer=setTimeout(()=>{w.terminate();resolve({timeout:true});},Number(process.env.PROBE_TIMEOUT_MS??60000));
  w.once('message',v=>{clearTimeout(timer);w.terminate();resolve(v);});w.once('error',e=>{clearTimeout(timer);resolve({crash:String(e)});});
 });rows.push({...job,...response});console.log(job.id,JSON.stringify(response));}}
 await Promise.all(Array.from({length:Math.min(4,jobs.length)},lane));
 rows.sort((a,b)=>a.id-b.id);
 fs.writeFileSync(new URL(`remaining-${process.env.PROBE_LABEL??mode}.json`,import.meta.url),JSON.stringify({implementation:execFileSync('git',['rev-parse','HEAD'],{encoding:'utf8'}).trim(),probeSettings:{timeoutMs:Number(process.env.PROBE_TIMEOUT_MS??60000),minimumLength:Number(process.env.PROBE_MINIMUM??1e-5),distanceMaxDepth:Number(process.env.PROBE_DEPTH??48),distanceTolerance:1e-9,diagnosticRuntime:Boolean(process.env.PROBE_RUNTIME)},rows},null,2)+'\n');
}
