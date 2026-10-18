import fs from 'node:fs';
import * as g from '../../test_portable/build/dev/javascript/svg_path/svg_path.mjs';
import * as csg from '../../test_portable/build/dev/javascript/svg_path/svg_path/csg.mjs';
import {path,unwrap} from './triage-geometry.mjs';
const cases=JSON.parse(fs.readFileSync(new URL('./captured-cases.json',import.meta.url)));
const ids=JSON.parse(fs.readFileSync(new URL('./discrepancy-queue.json',import.meta.url))).filter(c=>c.kind==='boolean').map(c=>c.id);
const dist=(a,b)=>Math.hypot(a.x-b.x,a.y-b.y);
const shape=s=>JSON.stringify(Object.fromEntries(Object.entries(s).filter(([k])=>!['start','end'].includes(k))));
const rows=[];
for(const c of cases.filter(c=>ids.includes(c.id))){
 const fn={Or:csg.union,And:csg.intersection,Not:csg.difference,Xor:csg.symmetric_difference}[c.operation];
 const returned=fn(path(c.input),path(c.other),new g.Nonzero());
 if(!returned.isOk()){rows.push({id:c.id,operation:c.operation,error:returned[0].constructor.name});continue;}
 const result=returned[0];
 const edges=Array.from(result.build.graph.edges);
 const segments=[];
 for(const sub of result.path.subpaths)for(const out of sub.segments){
  const matches=edges.flatMap(e=>[e.segment,g.segment_reverse(e.segment)].filter(s=>s.constructor===out.constructor&&shape(s)===shape(out)).map(s=>({id:e.id,s,gap:Math.max(dist(s.start,out.start),dist(s.end,out.end))}))).sort((a,b)=>a.gap-b.gap);
  const m=matches[0];
  segments.push(m?{edge_id:m.id,type:out.constructor.name,endpoint_movement:m.gap,midpoint_movement:dist(unwrap(g.segment_point(m.s,.5)),unwrap(g.segment_point(out,.5)))}:{unmatched:true,type:out.constructor.name});
 }
 rows.push({id:c.id,operation:c.operation,tolerance:csg.default_options().tolerance,segments});
}
console.log(JSON.stringify(rows,null,2));
