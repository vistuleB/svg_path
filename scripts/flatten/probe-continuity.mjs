// Explicit audit-only endpoint reconciliation. Original captures stay unchanged.
import fs from 'node:fs';
import {Worker,isMainThread,parentPort,workerData} from 'node:worker_threads';
import {execFileSync} from 'node:child_process';
import * as distance from '../../test_portable/build/dev/javascript/svg_path/svg_path/distance.mjs';
import * as g from '../../test_portable/build/dev/javascript/svg_path/svg_path.mjs';
import {cap,makePolygonAdapter} from './continuity-adapter.mjs';
process.env.FLATTEN_LIBRARY_ONLY='1';
const {pieces,compare,errorDetails}=await import('./compare-arc-circle.mjs');
const calls=fs.readFileSync(new URL('polygons-calls.jsonl',import.meta.url),'utf8').trim().split('\n').map(JSON.parse);
const ids=[3115,4278,4279,4280,4281,4282,4291,4292,4293,4294,4295,4296];

function execute({id,policy}){
 const adjustments=[];
 const adaptPolygon=makePolygonAdapter(policy,adjustments);
 const start=performance.now();
 let outputs;
 const result=compare(calls[id-1],{adaptPolygon,observeBoolean:(actual,expected)=>{outputs={actual,expected};}});
 let boundarySamples;
 if(outputs){
  boundarySamples=[];
  for(const [label,source,target] of [['actual-to-reference',outputs.actual,outputs.expected],['reference-to-actual',outputs.expected,outputs.actual]]){
   let checked=0,maxDistance=0,worst=null;const failures=[];
   for(const [index,segment] of [...source.subpaths].flatMap(s=>[...s.segments]).entries())for(const t of [0,.25,.5,.75,1]){
    const p=g.segment_point(segment,t);if(!p.isOk()){failures.push({index,t,error:errorDetails(p[0])});continue;}
    const d=distance.path_distance(p[0],target);if(!d.isOk()){failures.push({index,t,error:errorDetails(d[0])});continue;}
    checked++;if(d[0]>maxDistance){maxDistance=d[0];worst={index,t,point:p[0]};}
   }
   boundarySamples.push({label,checked,maxDistance,worst,failures});
  }
 }
 return {id,policy,cap,adjustments,result,boundarySamples,ms:performance.now()-start};
}
if(!isMainThread){try{parentPort.postMessage(execute(workerData));}catch(e){parentPort.postMessage({...workerData,error:errorDetails(e),stack:e.stack});}}
else{
 const jobs=ids.flatMap(id=>['end-to-next-start','start-to-previous-end'].map(policy=>({id,policy})));
 let cursor=0;const rows=[];
 async function lane(){while(cursor<jobs.length){const job=jobs[cursor++];const result=await new Promise(resolve=>{
  const w=new Worker(new URL(import.meta.url),{workerData:job});
  const timer=setTimeout(()=>{w.terminate();resolve({...job,timeout:true});},120000);
  w.once('message',r=>{clearTimeout(timer);w.terminate();resolve(r);});
  w.once('error',e=>{clearTimeout(timer);resolve({...job,crash:String(e)});});
 });rows.push(result);console.log(job.id,job.policy,JSON.stringify(result.result??result),result.ms??'');}}
 await Promise.all([lane(),lane()]);rows.sort((a,b)=>a.id-b.id||a.policy.localeCompare(b.policy));
 fs.writeFileSync(new URL('remaining-continuity-replay.json',import.meta.url),JSON.stringify({implementation:execFileSync('git',['rev-parse','HEAD'],{encoding:'utf8'}).trim(),cap,policies:['end-to-next-start','start-to-previous-end'],timeoutMs:120000,rows},null,2)+'\n');
}
