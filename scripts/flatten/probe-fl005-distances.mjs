// Replay every captured distanceTo query without replacing historical reports.
import fs from 'node:fs';
import {Worker,isMainThread,parentPort,workerData} from 'node:worker_threads';
process.env.FLATTEN_LIBRARY_ONLY='1';
const {compare,errorDetails}=await import('./compare-arc-circle.mjs');
if(!isMainThread){
 try{parentPort.postMessage(compare(workerData.call));}catch(e){parentPort.postMessage({status:'error',error:errorDetails(e)});}
}else{
 const jobs=[];
 for(const batch of ['chains','polygons','arc-circle','primitives','linear','residual','arc-extra']){
  const calls=fs.readFileSync(new URL(`${batch}-calls.jsonl`,import.meta.url),'utf8').trim().split('\n').map(JSON.parse);
  calls.forEach((call,i)=>{if(call.operation==='distanceTo')jobs.push({batch,id:i+1,call});});
 }
 let cursor=0;const rows=[];
 async function lane(){while(cursor<jobs.length){const job=jobs[cursor++];
  const comparison=await new Promise(resolve=>{
   const worker=new Worker(new URL(import.meta.url),{workerData:job});
   const finish=value=>{clearTimeout(timer);worker.terminate();resolve(value);};
   const timer=setTimeout(()=>finish({status:'timeout'}),5000);
   worker.once('message',finish);worker.once('error',e=>finish({status:'error',message:String(e)}));
  });
  rows.push({batch:job.batch,id:job.id,comparison});
 }}
 await Promise.all(Array.from({length:4},lane));
 rows.sort((a,b)=>a.batch.localeCompare(b.batch)||a.id-b.id);
 const counts={};for(const r of rows)counts[r.comparison.status]=(counts[r.comparison.status]??0)+1;
 fs.writeFileSync(new URL('remaining-fl005-distance-replay.json',import.meta.url),JSON.stringify({description:'Working-tree FL005 line/arc and arc/arc improvements',timeoutMs:5000,counts,rows},null,2)+'\n');
 console.log(counts);
 for(const row of rows)if(!['match','scope-difference'].includes(row.comparison.status))console.log(row);
}
