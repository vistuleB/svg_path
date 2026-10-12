import fs from 'node:fs';
import {Worker,isMainThread,parentPort,workerData} from 'node:worker_threads';
if(isMainThread) {
 const {fixtures}=JSON.parse(fs.readFileSync(new URL('./containment.json',import.meta.url)));
 let index=0; const results=[];
 async function run(){while(index<fixtures.length){const f=fixtures[index++];
  const result=await new Promise(resolve=>{
   const w=new Worker(new URL(import.meta.url),{workerData:f});
   const timer=setTimeout(()=>{w.terminate();resolve({status:'timeout'});},10000);
   w.once('message',r=>{clearTimeout(timer);w.terminate();resolve(r);});
   w.once('error',e=>{clearTimeout(timer);resolve({status:'harness-error',error:String(e)});});
  });results.push({id:f.id,block:f.block,...result});
 }}
 await Promise.all([run(),run()]);results.sort((a,b)=>a.id-b.id);
 fs.writeFileSync(new URL('./containment-screening.json',import.meta.url),JSON.stringify(results,null,2)+'\n');
 console.log(results.reduce((a,r)=>(a[r.status]=(a[r.status]||0)+1,a),{}));
 console.log(results.filter(r=>r.status!=='match'));
}else{
 const s=await import('../../test_portable/build/dev/javascript/svg_path/svg_path.mjs');
 const containment=await import('../../test_portable/build/dev/javascript/svg_path/svg_path/containment.mjs');
 const {toList,Ok}=await import('../../test_portable/build/dev/javascript/svg_path/gleam.mjs');
 const f=workerData;
 const path=s.path_combine(toList(f.geometry.subpaths.filter(p=>p.curves.length).map(p=>{
  let sub=s.subpath_assert(toList(p.curves.map(c=>new s.CubicBezier(...[0,2,4,6].map(i=>new s.Point(c[i],c[i+1]))))));
  if(p.closed)sub=s.subpath_assert_close(sub);
  return s.subpath_as_path(sub);
 })));
 const r=containment.path_containment(new s.Point(...f.point),path,f.geometry.fillRule==='evenodd'?new s.EvenOdd():new s.Nonzero());
 function clean(v){return v&&typeof v==='object'?{type:v.constructor.name,...Object.fromEntries(Object.entries(v).map(([k,x])=>[k,clean(x)]))}:v;}
 if(!(r instanceof Ok))parentPort.postMessage({status:'library-error',error:clean(r[0])});
 else {const actual=!(r[0] instanceof s.Outside);parentPort.postMessage({status:actual===f.expected?'match':'discrepancy',expected:f.expected,actual,classification:clean(r[0])});}
}
