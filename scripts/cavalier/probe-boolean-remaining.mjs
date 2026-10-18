import fs from 'node:fs';
import * as g from '../../test_portable/build/dev/javascript/svg_path/svg_path.mjs';
import * as csg from '../../test_portable/build/dev/javascript/svg_path/svg_path/csg.mjs';
import * as contain from '../../test_portable/build/dev/javascript/svg_path/svg_path/containment.mjs';
import * as distance from '../../test_portable/build/dev/javascript/svg_path/svg_path/distance.mjs';
import * as area from '../../test_portable/build/dev/javascript/svg_path/svg_path/area.mjs';
import {toList} from '../../test_portable/build/dev/javascript/prelude.mjs';
const unwrap=r=>{if(!r.isOk())throw r[0];return r[0]},P=v=>new g.Point(v[0],v[1]);
function path(input){const vs=input.vertices;const ss=vs.map((a,i)=>{const b=vs[(i+1)%vs.length],bulge=a[2];if(!bulge)return new g.Line(P(a),P(b));const r=Math.hypot(b[0]-a[0],b[1]-a[1])*(1+bulge*bulge)/(4*Math.abs(bulge));return new g.Arc(P(a),new g.Point(r,r),0,Math.abs(bulge)>1,bulge>0,P(b));});return new g.Path(toList([unwrap(g.subpath_close(unwrap(g.subpath(toList(ss)))))]));}
const encode=x=>x===null||typeof x!=='object'?x:Array.isArray(x)?x.map(encode):{type:x.constructor.name,...Object.fromEntries(Object.entries(x).map(([k,v])=>[k,encode(v)]))};
const cases=JSON.parse(fs.readFileSync(new URL('./captured-cases.json',import.meta.url)));
const flags=JSON.parse(fs.readFileSync(new URL('./discrepancy-queue.json',import.meta.url)));
const ids=new Set(flags.filter(r=>r.kind==='boolean'&&(r.status==='error'||['Not','Xor'].includes(cases.find(c=>c.id===r.id)?.operation))).map(r=>r.id));
const outFile=new URL('./boolean-remaining.jsonl',import.meta.url);
const done=new Set(fs.existsSync(outFile)?fs.readFileSync(outFile,'utf8').trim().split('\n').filter(Boolean).map(l=>JSON.parse(l).id):[]);
for(const c of cases.filter(c=>ids.has(c.id)&&!done.has(c.id))){
 const row={id:c.id,test:c.test,operation:c.operation};
 try{
  const a=path(c.input),b=path(c.other);
  const fn={Or:csg.union_path,And:csg.intersection_path,Not:csg.difference_path,Xor:csg.symmetric_difference_path}[c.operation];
  const result=fn(a,b,new g.Nonzero());
  if(!result.isOk()){row.error=encode(result[0]);}
  else {
   const out=result[0];row.signed_area=Array.from(out.subpaths).reduce((sum,s)=>sum+area.signed_subpath(s),0);row.contours=Array.from(out.subpaths).length;
   row.checked=0;row.boundary_skipped=0;row.mismatches=[];
   // Sample each side of output boundaries; do not assume contour layout.
   for(const sub of out.subpaths)for(const segment of sub.segments)for(const t of [.25,.5,.75]){
    const p=unwrap(g.segment_point(segment,t)),v=unwrap(g.segment_derivative(segment,t)),length=Math.hypot(v.x,v.y);if(!length)continue;
    for(const step of [-1e-4,-1e-5,1e-5,1e-4]){
     const q=new g.Point(p.x-step*v.y/length,p.y+step*v.x/length);
     const ca=unwrap(contain.path_containment(q,a,new g.Nonzero())),cb=unwrap(contain.path_containment(q,b,new g.Nonzero())),co=unwrap(contain.path_containment(q,out,new g.Nonzero()));
     if([ca,cb,co].some(x=>!(x instanceof g.Inside)&&!(x instanceof g.Outside))){row.boundary_skipped++;continue;}
     const ia=ca instanceof g.Inside,ib=cb instanceof g.Inside,actual=co instanceof g.Inside;
     const expected={Or:ia||ib,And:ia&&ib,Not:ia&&!ib,Xor:ia!==ib}[c.operation];row.checked++;
     if(actual!==expected&&row.mismatches.length<12){
      const da=unwrap(distance.path_distance(q,a)),db=unwrap(distance.path_distance(q,b)),dout=unwrap(distance.path_distance(q,out));
      if(Math.min(da,db,dout)>1e-7)row.mismatches.push({point:q,input_a:ia,input_b:ib,actual,expected,distances:[da,db,dout]});
     }
    }
   }
  }
 }catch(e){row.probe_error=encode(e);}
 fs.appendFileSync(outFile,JSON.stringify(row)+'\n');console.log(c.id,row.error?.type??row.probe_error?.type??`${row.checked} checked, ${row.mismatches.length} witnesses`);
}
