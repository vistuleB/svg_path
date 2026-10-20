import fs from 'node:fs';
import {Worker,isMainThread,parentPort,workerData} from 'node:worker_threads';
import * as g from '../../test_portable/build/dev/javascript/svg_path/svg_path.mjs';
import * as ix from '../../test_portable/build/dev/javascript/svg_path/svg_path/intersections.mjs';
import * as ar from '../../test_portable/build/dev/javascript/svg_path/svg_path/arrangement.mjs';
import {toList} from '../../test_portable/build/dev/javascript/prelude.mjs';
if(!isMainThread){
 const plain=JSON.parse(fs.readFileSync(new URL(workerData.file,import.meta.url)));
 let segments=plain.map(s=>new g.Arc(new g.Point(s.start.x,s.start.y),new g.Point(s.radius.x,s.radius.y),s.x_axis_rotation,s.large_arc,s.sweep,new g.Point(s.end.x,s.end.y)));
 if(workerData.reverse)segments=segments.map(g.segment_reverse);
 const t=performance.now();
 const r=workerData.operation==='intersections'?ix.segment(...segments):ar.build(toList(segments.map(s=>new g.Path(toList([g.subpath(toList([s]))[0]])))),1e-9,1e-9);
 parentPort.postMessage({milliseconds:performance.now()-t,result:r.isOk()?workerData.operation==='intersections'?{hits:[...r[0]]}:{edges:[...r[0].graph.edges].length,vertices:[...r[0].graph.vertices].length}:{error:r[0].constructor.name,...r[0]}});
}else{
 const rows=[];
 for(const file of ['tangent-timeout-original-pair.json','tangent-timeout-reduced-pair.json'])for(const operation of ['intersections','arrangement'])for(const reverse of [false,true]){
  const test={file,operation,reverse};
  const result=await new Promise(resolve=>{
   const w=new Worker(new URL(import.meta.url),{workerData:test});
   const timer=setTimeout(()=>{w.terminate();resolve({status:'timeout',seconds:15})},15000);
   w.once('message',r=>{clearTimeout(timer);w.terminate();resolve(r)});
   w.once('error',e=>{clearTimeout(timer);w.terminate();resolve({harnessError:String(e)})});
  });rows.push({...test,...result});console.error(test,result);
 }
 console.log(JSON.stringify(rows,null,2));
}
