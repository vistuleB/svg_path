import fs from 'node:fs';
import * as g from '../../test_portable/build/dev/javascript/svg_path/svg_path.mjs';
import * as intr from '../../test_portable/build/dev/javascript/svg_path/svg_path/intersections.mjs';
const cases=JSON.parse(fs.readFileSync(new URL('./elementary-triage-cases.json',import.meta.url)));
const vals=s=>[...s.matchAll(/(?:x|y|bulge): ([^,} ]+)/g)].map(m=>Number(m[1]));
const unwrap=r=>{if(!r.isOk())throw r[0];return r[0]};
const P=v=>new g.Point(v[0],v[1]);
function seg(a,b){const r=Math.hypot(b[0]-a[0],b[1]-a[1])*(1+a[2]*a[2])/(4*Math.abs(a[2]));return new g.Arc(P(a),new g.Point(r,r),0,Math.abs(a[2])>1,a[2]>0,P(b));}
function circle(c,r){const a=[c[0]+r,c[1],1],b=[c[0]-r,c[1],1];return [seg(a,b),seg(b,a)];}
const rows=[];
for(const c of cases.filter(c=>['CC00013','CC00016','CC00070','CC00071','CC01188','CC01751','CC01752','CC01753'].includes(c.id))){
 const left=c.kind==='circle_circle_intr'?circle(vals(c.center1),+c.radius1):[seg(vals(c.v1),vals(c.v2))];
 const right=c.kind==='circle_circle_intr'?circle(vals(c.center2),+c.radius2):[seg(vals(c.u1),vals(c.u2))];
 const hits=[];
 for(const a of left)for(const b of right)for(const hit of unwrap(intr.segment(a,b))){
  const p=unwrap(g.segment_point(a,hit.left_t)),q=unwrap(g.segment_point(b,hit.right_t));
  hits.push({...hit,residual:Math.hypot(p.x-q.x,p.y-q.y)});
 }
 const endpoints=left.flatMap(a=>right.flatMap(b=>[a.start,a.end].flatMap(p=>[b.start,b.end].map(q=>Math.hypot(p.x-q.x,p.y-q.y)))));
 rows.push({id:c.id,hits,minimum_endpoint_gap:Math.min(...endpoints),default_tolerance:intr.default_options().tolerance});
}
console.log(JSON.stringify(rows,null,2));
