// Native quarter-circle endpoint gap: no upstream bulge conversion.
import * as g from './probe/build/dev/javascript/svg_path/svg_path.mjs';
import * as intersections from './probe/build/dev/javascript/svg_path/svg_path/intersections.mjs';
import * as overlap from './probe/build/dev/javascript/svg_path/svg_path/internal/overlap_detection.mjs';
const rows=[];
const encode=r=>r.isOk()?{ok:true,values:Array.from(r[0])}:{ok:false,error:{type:r[0].constructor.name,...r[0]}};
for(const shift of [0,1000]) for(const gap of [0,1e-12,1e-10,2e-9]) {
 const p=(x,y)=>new g.Point(x+shift,y+shift);
 const a=new g.Arc(p(1,0),new g.Point(1,1),0,false,true,p(0,1));
 const b=new g.Arc(p(0,1+gap),new g.Point(1,1),0,false,true,p(-1,2+gap));
 for(const tolerance of [1e-13,1e-9]) {
  const options=intersections.default_options();options.tolerance=tolerance;
  rows.push({shift,gap,actual_gap:b.start.y-a.end.y,tolerance,
   endpoint_matches:encode(overlap.point_parameters(b,a.end,tolerance)),
   intersections:encode(intersections.segment_with(a,b,options))});
 }
}
console.log(JSON.stringify(rows,null,2));
