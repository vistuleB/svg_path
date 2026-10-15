// Standalone native-API reproduction: no Flatten dependency or capture adapter.
import {Worker,isMainThread,parentPort,workerData} from 'node:worker_threads';
import fs from 'node:fs';
import * as g from '../../test_portable/build/dev/javascript/svg_path/svg_path.mjs';
import * as distance from '../../test_portable/build/dev/javascript/svg_path/svg_path/distance.mjs';
import * as intersections from '../../test_portable/build/dev/javascript/svg_path/svg_path/intersections.mjs';
if(!isMainThread) {
 Error.stackTraceLimit=80;
 const line=new g.Line(new g.Point(0,2),new g.Point(4,2));
 const arc=new g.Arc(new g.Point(3,0),new g.Point(3,3),0,false,true,new g.Point(0,3));
 try {
  const result=workerData==='intersection'?intersections.segment(line,arc):workerData==='segment-distance'?distance.segment_segment_closest_pair(line,arc):distance.path_path_closest_pair(g.segment_as_path(line),g.segment_as_path(arc));
  parentPort.postMessage({probe:workerData,result});
 } catch(e) {parentPort.postMessage({probe:workerData,error:String(e),stack:e.stack});}
} else {
 const rows=[];
 for(const probe of ['intersection','segment-distance','path-distance']) rows.push(await new Promise(resolve=>{
  const worker=new Worker(new URL(import.meta.url),{workerData:probe});
  const timer=setTimeout(()=>{worker.terminate();resolve({probe,timeout:true});},30000);
  worker.once('message',v=>{clearTimeout(timer);resolve(v);});
  worker.once('error',e=>{clearTimeout(timer);resolve({probe,error:String(e)});});
 }));
 fs.writeFileSync(new URL('distance-stack-probe.json',import.meta.url),JSON.stringify(rows,null,2)+'\n');
 for(const row of rows) console.log(row.probe,row.error??JSON.stringify(row.result)??'timeout');
}
