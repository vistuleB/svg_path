// Read-only adaptation of the original captured continuous-overlap records.
import fs from 'node:fs';
import {Worker,isMainThread,parentPort,workerData} from 'node:worker_threads';
import * as g from '../../test_portable/build/dev/javascript/svg_path/svg_path.mjs';
import * as intr from '../../test_portable/build/dev/javascript/svg_path/svg_path/intersections.mjs';
import * as encounters from '../../test_portable/build/dev/javascript/svg_path/svg_path/encounters.mjs';
const ok=r=>{if(!r.isOk())throw r[0];return r[0]};
const nums=s=>[...s.matchAll(/(?:x|y|bulge): (-?[\d.]+(?:e[+-]?\d+)?)/g)].map(m=>Number(m[1]));
const P=a=>new g.Point(a[0],a[1]);
const dist=(a,b)=>Math.hypot(a.x-b.x,a.y-b.y);
function segment(v,w){const p=P(v),q=P(w),b=v[2]??0;if(!b)return new g.Line(p,q);const r=Math.hypot(q.x-p.x,q.y-p.y)*(1+b*b)/(4*Math.abs(b));return new g.Arc(p,new g.Point(r,r),0,Math.abs(b)>1,b>0,q)}
function run(c){
 try{
  const tolerance=process.env.AUDIT_OVERLAP_TOLERANCE?Number(process.env.AUDIT_OVERLAP_TOLERANCE):1e-9;
  const pointTolerance=Math.max(1e-6,tolerance);
  let pairs,expected;
  if(c.kind==='circle_circle_intr'){
   const make=(s,r)=>{const [x,y]=nums(s);return [segment([x+r,y,1],[x-r,y]),segment([x-r,y,1],[x+r,y])]};
   const a=make(c.center1,Number(c.radius1)),b=make(c.center2,Number(c.radius2));pairs=a.flatMap((x,i)=>b.map((y,j)=>[x,y,i,j]));
  }else{
   const a=segment(nums(c.v1),nums(c.v2)),b=segment(nums(c.u1),nums(c.u2));pairs=[[a,b,0,0]];
   expected=c.kind==='line_line_intr'?[...c.result.matchAll(/seg2_t[01]: ([^,} ]+)/g)].map(m=>ok(g.segment_point(b,Number(m[1])))):[...c.result.matchAll(/Vector2 \{ x: ([^,]+), y: ([^}]+) \}/g)].map(m=>new g.Point(Number(m[1]),Number(m[2])));
  }
  const rows=[];let maxResidual=0;
  for(const [a,b,i,j] of pairs){
   const r=ok(encounters.segment_with(a,b,{...intr.default_options(),tolerance}));
   for(const o of r.overlaps){
    for(let k=0;k<=16;k++){const t=k/16;maxResidual=Math.max(maxResidual,dist(ok(g.segment_point(a,o.left_from+t*(o.left_to-o.left_from))),ok(g.segment_point(b,o.right_from+t*(o.right_to-o.right_from)))))}
    rows.push({left:i,right:j,...o});
   }
  }
  let endpointsMatch;
  if(expected){endpointsMatch=rows.length===1&&expected.length===2&&((dist(rows[0].start,expected[0])<=pointTolerance&&dist(rows[0].end,expected[1])<=pointTolerance)||(dist(rows[0].start,expected[1])<=pointTolerance&&dist(rows[0].end,expected[0])<=pointTolerance));}
  else endpointsMatch=rows.length===2&&rows.every(o=>Math.abs(o.left_from)<=1e-12&&Math.abs(o.left_to-1)<=1e-12&&Math.abs(o.right_to-o.right_from)>=1-1e-12);
  return {tolerance,status:endpointsMatch&&maxResidual<=tolerance?'match':'discrepancy',endpointsMatch,maxResidual,expected,overlaps:rows};
 }catch(e){return {status:'error',error:{type:e.constructor?.name,...e}}}
}
if(!isMainThread)parentPort.postMessage(run(workerData));
else{
 const cases=JSON.parse(fs.readFileSync(new URL('./captured-cases.json',import.meta.url))).filter(c=>typeof c.result==='string' && c.result.startsWith('Overlapping') && (!process.env.AUDIT_CASE_ID || c.id===process.env.AUDIT_CASE_ID));
 for(const c of cases){const r=await new Promise(resolve=>{const w=new Worker(new URL(import.meta.url),{workerData:c});const timer=setTimeout(()=>{w.terminate();resolve({status:'timeout'})},30000);w.once('message',r=>{clearTimeout(timer);resolve(r)});w.once('error',e=>{clearTimeout(timer);resolve({status:'harness-error',error:String(e)})})});console.log(JSON.stringify({id:c.id,test:c.test,kind:c.kind,...r}))}
}
