import fs from 'node:fs';
import * as g from '/tmp/csg-affine-focused/build/dev/javascript/svg_path/svg_path.mjs';
import * as csg from '/tmp/csg-affine-focused/build/dev/javascript/svg_path/svg_path/csg.mjs';
import {path,unwrap} from '/tmp/csg-affine-focused/triage-geometry.mjs';
const cases=JSON.parse(fs.readFileSync(new URL('./captured-cases.json',import.meta.url)));
const ids=JSON.parse(fs.readFileSync(new URL('./discrepancy-queue.json',import.meta.url))).filter(c=>c.kind==='boolean').map(c=>c.id);
const dist=(a,b)=>Math.hypot(a.x-b.x,a.y-b.y);
const shape=s=>JSON.stringify(Object.fromEntries(Object.entries(s).filter(([k])=>!['start','end'].includes(k))));
const rows=[];
for(const c of cases.filter(c=>ids.includes(c.id))){
 const fn={Or:csg.union,And:csg.intersection,Not:csg.difference,Xor:csg.symmetric_difference}[c.operation];
 globalThis.arcChecks=[];
 const returned=fn(path(c.input),path(c.other),new g.Nonzero());
 if(!returned.isOk()){rows.push({id:c.id,operation:c.operation,error:returned[0].constructor.name});continue;}
 const result=returned[0];
 const subpaths=Array.from(result.path.subpaths).map(s=>Array.from(s.segments));
 const exact=subpaths.every(ss=>ss.every((s,i)=>{const next=ss[(i+1)%ss.length];return s.end.x===next.start.x&&s.end.y===next.start.y}));
 rows.push({id:c.id,operation:c.operation,exactJoins:exact,checks:globalThis.arcChecks});
}
console.log(JSON.stringify(rows,null,2));
