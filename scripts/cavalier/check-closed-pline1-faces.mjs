import fs from 'node:fs';
import * as g from '../../test_portable/build/dev/javascript/svg_path/svg_path.mjs';
import * as contain from '../../test_portable/build/dev/javascript/svg_path/svg_path/containment.mjs';
import * as distance from '../../test_portable/build/dev/javascript/svg_path/svg_path/distance.mjs';
import {toList} from '../../test_portable/build/dev/javascript/prelude.mjs';
const r=JSON.parse(fs.readFileSync(new URL('./offset-closed-pline1-trace.json',import.meta.url))),args=r.offside.args;
const point=p=>new g.Point(p.x,p.y),segment=s=>s.type==='Line'?new g.Line(point(s.start),point(s.end)):new g.Arc(point(s.start),point(s.radius),s.x_axis_rotation,s.large_arc,s.sweep,point(s.end));
const unwrap=r=>{if(!r.isOk())throw r[0];return r[0]};
const source=new g.Path(toList([unwrap(g.subpath_close(unwrap(g.subpath(toList(args[0].zero_source.segments.map(segment))))))]));
const edgeIds=new Set(args[1].flatMap(i=>i.edges.map(e=>e.edge_id))),rows=[];
for(const e of args[3].graph.edges.filter(e=>edgeIds.has(e.id))){
 const s=segment(e.segment),p=unwrap(g.segment_point(s,.5)),faces=args[4].edge_faces.find(f=>f.edge_id===e.id),keptByFlood=r.flood.includes(faces.left_face)||r.flood.includes(faces.right_face);
 rows.push({id:e.id,point:p,keptByFlood,classification:unwrap(contain.path_containment(p,source,new g.Nonzero())).constructor.name,distance:unwrap(distance.path_distance(p,source)),faces});
}
console.log(JSON.stringify(rows,null,2));
