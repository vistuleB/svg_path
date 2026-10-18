import fs from 'node:fs';
import * as g from '../../test_portable/build/dev/javascript/svg_path/svg_path.mjs';
import * as intr from '../../test_portable/build/dev/javascript/svg_path/svg_path/intersections.mjs';
import * as overlap from '../../test_portable/build/dev/javascript/svg_path/svg_path/internal/overlap_detection.mjs';
import * as query from '../../test_portable/build/dev/javascript/svg_path/svg_path/internal/query.mjs';
const cases=JSON.parse(fs.readFileSync(new URL('./elementary-triage-cases.json',import.meta.url)));
const vals=s=>[...s.matchAll(/(?:x|y|bulge): ([^,} ]+)/g)].map(m=>Number(m[1]));
const unwrap=r=>{if(!r.isOk())throw r[0];return r[0]};
const P=v=>new g.Point(v[0],v[1]);
function seg(a,b){const r=Math.hypot(b[0]-a[0],b[1]-a[1])*(1+a[2]*a[2])/(4*Math.abs(a[2]));return new g.Arc(P(a),new g.Point(r,r),0,Math.abs(a[2])>1,a[2]>0,P(b));}
const rows=[];
for(const c of cases.filter(c=>['CC01751','CC01752','CC01753'].includes(c.id))){
 const a=seg(vals(c.v1),vals(c.v2)),b=seg(vals(c.u1),vals(c.u2));
 const magnitude=Math.max(...[a,b].flatMap(s=>Array.from(unwrap(query.segment_bounding_polygon(s))).flatMap(p=>[Math.abs(p.x),Math.abs(p.y)])));
 const internal=Math.max(1e-13,magnitude*3.552713678800501e-15);
 const endpoints=[0,1].map(t=>{const p=unwrap(g.segment_point(a,t));return {t,public_matches:Array.from(unwrap(overlap.point_parameters(b,p,1e-9))),internal_matches:Array.from(unwrap(overlap.point_parameters(b,p,internal)))};});
 const shifted=s=>new g.Arc(new g.Point(s.start.x+171,s.start.y+225.631646989571),s.radius,s.x_axis_rotation,s.large_arc,s.sweep,new g.Point(s.end.x+171,s.end.y+225.631646989571));
 rows.push({id:c.id,magnitude,internal_tolerance:internal,endpoints,native:Array.from(unwrap(intr.segment(a,b))),translated:Array.from(unwrap(intr.segment(shifted(a),shifted(b))))});
}
console.log(JSON.stringify(rows,null,2));
