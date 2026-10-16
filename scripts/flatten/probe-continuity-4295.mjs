import fs from 'node:fs';
import * as g from '../../test_portable/build/dev/javascript/svg_path/svg_path.mjs';
import * as ix from '../../test_portable/build/dev/javascript/svg_path/svg_path/intersections.mjs';
import * as ov from '../../test_portable/build/dev/javascript/svg_path/svg_path/overlaps.mjs';
import * as csg from '../../test_portable/build/dev/javascript/svg_path/svg_path/csg.mjs';
import * as area from '../../test_portable/build/dev/javascript/svg_path/svg_path/area.mjs';
import * as distance from '../../test_portable/build/dev/javascript/svg_path/svg_path/distance.mjs';
import {makePolygonAdapter} from './continuity-adapter.mjs';
const call=JSON.parse(fs.readFileSync(new URL('polygons-calls.jsonl',import.meta.url),'utf8').split('\n')[4294]);
const adapter=makePolygonAdapter('end-to-next-start',[]),left=adapter(call.input),right=adapter(call.arguments[0]),expected=adapter(call.result);
const unwrap=r=>{if(!r.isOk())throw r[0];return r[0];};
const rows=[];
const curved=[...left.subpaths].flatMap(s=>[...s.segments]).find(s=>s.radius.x===84.49938828627135);
const cutter=[...right.subpaths].flatMap(s=>[...s.segments])[1];
const query=r=>r.isOk()?{ok:true,values:[...r[0]]}:{ok:false,error:r[0]};
const pairQueries=[5e-7,5e-8,1e-9,1e-12].map(tolerance=>({tolerance,intersections:query(ix.segment_with(curved,cutter,Object.assign(ix.default_options(),{tolerance}))),overlaps:query(ov.segment_with(curved,cutter,tolerance))}));
fs.writeFileSync(new URL('remaining-continuity-4295-pair.json',import.meta.url),JSON.stringify({curved,cutter,centers:[g.arc_center_data(curved),g.arc_center_data(cutter)],pairQueries},null,2)+'\n');
for(const tolerance of [1e-6,1e-7,1e-8,1e-9])for(const minimum of [1e-5,1e-9]){
 const r=csg.intersection_with(left,right,new g.EvenOdd(),new csg.Options(tolerance,minimum));
 if(!r.isOk()){rows.push({tolerance,minimum,error:r[0]});continue;}
 const b=r[0];const output=[...b.path.subpaths].flatMap(s=>[...s.segments]);
 let maxBoundaryDistance=0;
 for(const s of output)for(const t of [0,.25,.5,.75,1])maxBoundaryDistance=Math.max(maxBoundaryDistance,unwrap(distance.path_distance(unwrap(g.segment_point(s,t)),expected)));
 const matchingEdges=output.map(segment=>{
  const candidates=[...b.build.graph.edges].filter(e=>e.segment.constructor===segment.constructor&&e.segment.radius?.x===segment.radius?.x);
  return {segment,closestStored:candidates.map(edge=>({edge,delta:Math.hypot(edge.segment.start.x-segment.start.x,edge.segment.start.y-segment.start.y)+Math.hypot(edge.segment.end.x-segment.end.x,edge.segment.end.y-segment.end.y)})).sort((a,b)=>a.delta-b.delta)[0]};
 });
 rows.push({tolerance,minimum,segments:output.length,area:area.signed_path(b.path),maxBoundaryDistance,matchingEdges,images:[...b.build.edge_images].map(e=>({id:e.edge_id,sources:[...e.sources]}))});
}
fs.writeFileSync(new URL('remaining-continuity-4295.json',import.meta.url),JSON.stringify(rows,null,2)+'\n');
for(const {matchingEdges,images,...r} of rows)console.log(r);
