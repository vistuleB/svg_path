import fs from 'node:fs';
import {Worker,isMainThread,parentPort,workerData} from 'node:worker_threads';
import * as g from '../../test_portable/build/dev/javascript/svg_path/svg_path.mjs';
import * as off from '../../test_portable/build/dev/javascript/svg_path/svg_path/offset.mjs';
import * as area from '../../test_portable/build/dev/javascript/svg_path/svg_path/area.mjs';
import * as measure from '../../test_portable/build/dev/javascript/svg_path/svg_path/measure.mjs';
import * as bounds from '../../test_portable/build/dev/javascript/svg_path/svg_path/bounds.mjs';
import {toList} from '../../test_portable/build/dev/javascript/prelude.mjs';
const unwrap=r=>{if(!r.isOk())throw r[0];return r[0]};
function compare({fixture:f,reverse,cycle}) {
 let phase='conversion';
 try {
  if(!f.vertices.length)return {status:'scope',reason:'Empty polyline has no start position; native empty subpath requires one.'};
  const vs=f.vertices.slice(cycle).concat(f.vertices.slice(0,cycle));
  const segments=vs.slice(0,f.closed?vs.length:vs.length-1).map((v,i)=>{
   const w=vs[(i+1)%vs.length],p=new g.Point(v[0],v[1]),q=new g.Point(w[0],w[1]),b=v[2];
   if(b===0)return new g.Line(p,q);
   const r=Math.hypot(w[0]-v[0],w[1]-v[1])*(1+b*b)/(4*Math.abs(b));
   return new g.Arc(p,new g.Point(r,r),0,Math.abs(b)>1,b>0,q);
  });
  let source=unwrap(g.subpath(toList(segments)));
  if(f.closed)source=unwrap(g.subpath_close(source));
  if(reverse)source=g.subpath_reverse(source);
  // Cavalier uses Cartesian left; our positive normal is visual left (opposite).
  phase='offset';
  const result=unwrap(off.subpath(source,(reverse?1:-1)*f.offset,new off.Round(),new off.Butt()));
  phase='properties';
  const actual=Array.from(result.subpaths).map(s=>{
   const b=unwrap(bounds.subpath_bounding_box(s));
   return {area:f.closed?area.signed_subpath(s)*(reverse?-1:1):0,length:unwrap(measure.subpath_length(s)),bounds:[b.min.x,b.min.y,b.max.x,b.max.y],closed:g.subpath_is_closed(s)};
  });
  const remaining=[...actual];
  const matched=f.expected.every(e=>{
   const i=remaining.findIndex(a=>[a.area-e.area,a.length-e.length,...a.bounds.map((v,i)=>v-e.bounds[i])].every(v=>Math.abs(v)<=1e-4));
   if(i<0)return false;remaining.splice(i,1);return true;
  })&&remaining.length===0;
  return {status:matched?'match':'discrepancy',actual,expected:f.expected};
 }catch(e){return {status:'error',phase,error:{type:e.constructor?.name,...e}};}
}
if(!isMainThread){parentPort.postMessage(compare(workerData));}
else {
 const fixtures=JSON.parse(fs.readFileSync(new URL('offset-simple-fixtures.json',import.meta.url)));
 const results=[];
 for(const fixture of fixtures)for(const reverse of [false,true])for(let cycle=0;cycle<(fixture.closed?fixture.vertices.length:1);cycle++){
  const job={fixture,reverse,cycle};
  const result=await new Promise(resolve=>{
   const w=new Worker(new URL(import.meta.url),{workerData:job});
   const timer=setTimeout(()=>{w.terminate();resolve({status:'timeout',seconds:30})},30000);
   w.once('message',r=>{clearTimeout(timer);resolve(r)});
   w.once('error',e=>{clearTimeout(timer);resolve({status:'harness-error',error:String(e)})});
  });
  results.push({name:fixture.name,reverse,cycle,...result});
  console.log(fixture.name,reverse,cycle,result.status);
 }
 fs.writeFileSync(new URL('offset-simple-results.json',import.meta.url),JSON.stringify(results,null,2)+'\n');
 console.log(results.reduce((a,r)=>(a[r.status]=(a[r.status]??0)+1,a),{}));
}
