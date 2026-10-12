// Diagnostic inventory: failures are recorded, not repaired or asserted away.
import fs from 'node:fs';
import {Worker,isMainThread,parentPort,workerData} from 'node:worker_threads';
const fixtures=JSON.parse(fs.readFileSync(new URL('./bounds.json',import.meta.url))).fixtures.filter(f=>!process.env.BOUNDS_IDS||process.env.BOUNDS_IDS.split(',').map(Number).includes(f.id));
if(isMainThread){
 const results=[];let next=0;
 async function run(){while(next<fixtures.length){const f=fixtures[next++];const result=await new Promise(resolve=>{const w=new Worker(new URL(import.meta.url),{workerData:f});const timer=setTimeout(()=>{w.terminate();resolve({status:'timeout',limitMs:30000});},30000);w.once('message',r=>{clearTimeout(timer);w.terminate();resolve(r);});w.once('error',e=>{clearTimeout(timer);resolve({status:'harness-error',error:String(e)});});});results.push({id:f.id,block:f.block,property:f.property,strokeFittingTolerance:Number(process.env.BOUNDS_FITTING_TOLERANCE??0.01),...result});if(results.length%10===0)console.log(`${results.length}/${fixtures.length}`);}}
 await Promise.all([run(),run()]);results.sort((a,b)=>a.id-b.id);
 fs.writeFileSync(new URL(process.env.BOUNDS_REPORT??'./bounds-screening.json',import.meta.url),JSON.stringify(results,null,2)+'\n');
 console.log(results.reduce((a,r)=>(a[r.status]=(a[r.status]??0)+1,a),{}));
}else{
 const s=await import('../../test_portable/build/dev/javascript/svg_path/svg_path.mjs');
 const bounds=await import('../../test_portable/build/dev/javascript/svg_path/svg_path/bounds.mjs');
 const stroke=await import('../../test_portable/build/dev/javascript/svg_path/svg_path/stroke.mjs');
 const offset=await import('../../test_portable/build/dev/javascript/svg_path/svg_path/offset.mjs');
 const transform=await import('../../test_portable/build/dev/javascript/svg_path/svg_path/transform.mjs');
 const {Ok,toList}=await import('../../test_portable/build/dev/javascript/svg_path/gleam.mjs');
 const f=workerData;let stage='input';const unwrap=r=>{if(!(r instanceof Ok))throw r;return r[0];};
 const clean=v=>v&&typeof v==='object'?{type:v.constructor.name,...Object.fromEntries(Object.entries(v).map(([k,x])=>[k,clean(x)]))}:v;
 try{
  let path=s.path_combine(toList(f.subpaths.map(p=>{if(!p.curves.length)return s.subpath_as_path(s.subpath_empty(new s.Point(...p.start)));let sub=unwrap(s.subpath(toList(p.curves.map(c=>new s.CubicBezier(...[0,2,4,6].map(i=>new s.Point(c[i],c[i+1])))))));if(p.closed)sub=unwrap(s.subpath_close(sub));return s.subpath_as_path(sub);})));
  const matrix=transform.matrix(...f.matrix);
  if(f.property==='strokeBounds'&&f.stroke){
   const join=f.join==='miter'?new offset.Miter(f.miterLimit):f.join==='bevel'?new offset.Bevel():new offset.Round();
   const cap=f.cap==='square'?new offset.Square():f.cap==='round'?new offset.RoundCap():new offset.Butt();
   if(!f.strokeScaling)path=unwrap(transform.path(path,matrix));
   stage='stroke';const options=offset.default_options();if(process.env.BOUNDS_FITTING_TOLERANCE)options.fitting.tolerance=Number(process.env.BOUNDS_FITTING_TOLERANCE);path=unwrap(stroke.path_with(path,f.width/(f.strokeScaling?1:f.zoom),join,cap,options));
   stage='transform';if(f.strokeScaling)path=unwrap(transform.path(path,matrix));
  }else if(f.property!=='internalBounds'){stage='transform';path=unwrap(transform.path(path,matrix));}
  stage='bounds';const b=unwrap(bounds.path_bounding_box(path));
  const actual=f.property==='position'?[(b.min.x+b.max.x)/2,(b.min.y+b.max.y)/2]:[b.min.x,b.min.y,b.max.x-b.min.x,b.max.y-b.min.y];
  const error=Math.max(...actual.map((x,i)=>Math.abs(x-f.expected[i]))),tolerance=0.00002;
  parentPort.postMessage({status:error<=tolerance?'match':'discrepancy',actual,expected:f.expected,error,tolerance});
 }catch(error){parentPort.postMessage({status:'library-error',stage,error:clean(error)});}
}
