import fs from 'node:fs';
import {Worker, isMainThread, parentPort, workerData} from 'node:worker_threads';
import * as geometry from '../../test_portable/build/dev/javascript/svg_path/svg_path.mjs';
import * as intersections from '../../test_portable/build/dev/javascript/svg_path/svg_path/intersections.mjs';
function segment(ps) {
  const points=ps.map(([x,y])=>new geometry.Point(x,y));
  if(points.length===2) return new geometry.Line(...points);
  if(points.length===3) return new geometry.QuadraticBezier(...points);
  if(points.length===4) return new geometry.CubicBezier(...points);
  throw Error('No zero-order segment adaptation');
}
function evaluate(ps,t) {
  let points=ps.map(p=>p.slice());
  while(points.length>1) points=points.slice(1).map((p,i)=>p.map((v,j)=>(1-t)*points[i][j]+t*v));
  return points[0];
}
if(!isMainThread) {
  const result=intersections.segment(segment(workerData.left),segment(workerData.right));
  parentPort.postMessage(result.isOk()?{ok:true,values:[...result[0]]}:{ok:false,error:result[0].constructor.name,details:result[0]});
} else {
  const calls=fs.readFileSync(new URL(process.env.FLO_CALLS ?? 'intersection-calls.jsonl',import.meta.url),'utf8').trim().split('\n').map(JSON.parse);
  const rows=[];
  let cursor=0;
  async function lane() {
  while(cursor<calls.length) {
    const index=cursor++; const c=calls[index];
    let status,result;
    if(c.left.length===1 || c.right.length===1) status='point-input-api-difference';
    else {
      result=await new Promise(resolve=>{
        const worker=new Worker(new URL(import.meta.url),{workerData:c});
        const timer=setTimeout(()=>{worker.terminate();resolve({timeout:true});},5000);
        worker.once('message',r=>{clearTimeout(timer);resolve(r);});
        worker.once('error',e=>{clearTimeout(timer);resolve({crash:String(e)});});
      });
      const overlap=c.intersections.some(x=>x.kind===5);
      if(result.timeout || result.crash) status='needs-investigation';
      else if(!result.ok) status=overlap && result.error==='OverlappingSegments'?'overlap-api-difference':'needs-investigation';
      else {
        result.residuals=result.values.map(x=>{
          const a=evaluate(c.left,x.left_t),b=evaluate(c.right,x.right_t);
          return Math.hypot(a[0]-b[0],a[1]-b[1]);
        });
        const scale=Math.max(1,...c.left.flat().map(Math.abs),...c.right.flat().map(Math.abs));
        result.residualCheck=result.residuals.every(d=>d<=1e-9+64*Number.EPSILON*scale);
        // Diagnostic parameter matching, not an assertion of our public accuracy.
        const edges=c.intersections.map(x=>result.values.map((v,i)=>Math.max(Math.abs(x.t1-v.left_t),Math.abs(x.t2-v.right_t))<=1e-7?i:-1).filter(i=>i>=0));
        const owners=new Map();
        function match(i,seen=new Set()) {
          for(const j of edges[i]) if(!seen.has(j)) {
            seen.add(j);
            if(!owners.has(j)||match(owners.get(j),seen)) {owners.set(j,i);return true;}
          }
          return false;
        }
        result.matchedReferenceCount=edges.reduce((n,_,i)=>n+Number(match(i)),0);
        status=!overlap && result.residualCheck && result.values.length===c.intersections.length && result.matchedReferenceCount===c.intersections.length?'matches-at-diagnostic-tolerance':'needs-investigation';
      }
    }
    if (status==='needs-investigation' && result?.error==='InternalOverlapClassificationInconsistency') {
      const a=JSON.stringify(c.left), b=JSON.stringify(c.right);
      const line='[[1,1],[2,2]]', curve='[[0,0],[3,3],[0.5,0.5]]';
      if ((a===line && b===curve)||(a===curve && b===line)) status='confirmed-overlap-classification-bug';
    }
    rows.push({call:index+1,file:c.file,test:c.test,left:c.left,right:c.right,reference:c.intersections,status,...(result?{result}:{})});
  }
  }
  await Promise.all(Array.from({length:4},()=>lane()));
  rows.sort((a,b)=>a.call-b.call);
  const counts=Object.fromEntries([...new Set(rows.map(r=>r.status))].map(s=>[s,rows.filter(r=>r.status===s).length]));
  fs.writeFileSync(new URL(process.env.FLO_RESULTS ?? 'intersection-results.json',import.meta.url),JSON.stringify({counts,rows},null,2)+'\n');
  console.log(counts);
  for(const r of rows.filter(r=>r.status==='needs-investigation')) console.log(r.call,r.test,r.reference.length,r.result.ok?r.result.values.length:r.result.error??r.result);
}
