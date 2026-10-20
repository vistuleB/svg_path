// Isolate coordinate queries behind the reduced endpoint-search error.
import * as g from './probe/build/dev/javascript/svg_path/svg_path.mjs';
import * as q from './probe/build/dev/javascript/svg_path/svg_path/internal/query.mjs';
const encode=r=>r.isOk()?{ok:true,values:Array.from(r[0])}:{ok:false,error:{type:r[0].constructor.name,...r[0]}};
const rows=[];
for(const gap of [0,5e-13,1e-12,2e-12,1e-10]) {
 const a=new g.Arc(new g.Point(1,0),new g.Point(1,1),0,false,true,new g.Point(0,1));
 const b=new g.Arc(new g.Point(0,1+gap),new g.Point(1,1),0,false,true,new g.Point(-1,2+gap));
 for(const [name,segment,point] of [['a at b start',a,b.start],['b at a end',b,a.end]]) {
  for(const axis of ['x','y']) {
   const options=q.default_crossing_options();options.signed_line_distance_tolerance=1e-12;
   const direction=axis==='x'?new g.Point(0,1):new g.Point(1,0);
   rows.push({gap,name,axis,result:encode(g.segment_ray_crossings_with(segment,point,direction,options))});
  }
 }
}
console.log(JSON.stringify(rows,null,2));
