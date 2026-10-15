// Diagnostic only: isolate calls so exceptions/timeouts do not abort the sweep.
import fs from 'node:fs';
import {Worker,isMainThread,parentPort,workerData} from 'node:worker_threads';
const root=new URL('./',import.meta.url);
if(!isMainThread){
 const base=workerData.base??new URL('../../test_portable/build/dev/javascript/',import.meta.url).href;
 const g=await import(base+'svg_path/svg_path.mjs'),d=await import(base+'svg_path/svg_path/distance.mjs');
 globalThis.projectionAudit={inspections:0,byDepth:{},terminalCount:0};
 const s=ps=>new (ps.length===2?g.Line:g.CubicBezier)(...ps.map(p=>new g.Point(...p)));
 const start=performance.now();
 try{const result=d.segment_segment_closest_pair(s(workerData.a),s(workerData.b));parentPort.postMessage({ok:result.isOk(),value:result[0],elapsedMs:performance.now()-start,metrics:globalThis.projectionAudit});}
 catch(e){parentPort.postMessage({exception:String(e),stack:e.stack,elapsedMs:performance.now()-start,metrics:globalThis.projectionAudit});}
}else{
 const fixtures=[
 {name:'upstream',a:[[100000,100000],[100001,100010],[100007,100003],[100010,100000]],b:[[100000,100005.18996761437],[100010,100005.18996761437]]},
 {name:'translated',a:[[0,0],[1,10],[7,3],[10,0]],b:[[0,5.18996761437],[10,5.18996761437]]},
 {name:'integer-gap',a:[[0,0],[1,10],[7,3],[10,0]],b:[[0,6],[10,6]]},
 {name:'symmetric-unit',a:[[0,0],[0,1],[1,1],[1,0]],b:[[0,1],[1,1]]},
 {name:'symmetric-ten',a:[[0,0],[0,10],[10,10],[10,0]],b:[[0,10],[10,10]]},
 ];
 const rows=[];
 for(const fixture of fixtures.filter(f=>!process.env.FLO_CASE||f.name===process.env.FLO_CASE)){const result=await new Promise(resolve=>{
 const w=new Worker(new URL(import.meta.url),{workerData:{...fixture,base:process.env.FLO_JS_BASE}});
 const timer=setTimeout(()=>{w.terminate();resolve({timeout:true});},Number(process.env.FLO_TIMEOUT_MS??10000));
 w.once('message',r=>{clearTimeout(timer);resolve(r);});w.once('error',e=>{clearTimeout(timer);resolve({workerError:String(e)});});
 });rows.push({...fixture,...result});console.log(fixture.name,JSON.stringify(result));}
 fs.writeFileSync(new URL(process.env.FLO_REPORT??'stack-investigation.json',root),JSON.stringify(rows,null,2)+'\n');
}
