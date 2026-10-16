import fs from 'node:fs';
import * as g from '../../test_portable/build/dev/javascript/svg_path/svg_path.mjs';
import * as ix from '../../test_portable/build/dev/javascript/svg_path/svg_path/intersections.mjs';
const pair=JSON.parse(fs.readFileSync(new URL('remaining-continuity-4295-pair.json',import.meta.url)));
const analytic=JSON.parse(fs.readFileSync(new URL('remaining-continuity-4295-analytic.json',import.meta.url)));
const arc=s=>new g.Arc(new g.Point(s.start.x,s.start.y),new g.Point(s.radius.x,s.radius.y),s.x_axis_rotation,s.large_arc,s.sweep,new g.Point(s.end.x,s.end.y));
const a=arc(pair.curved),b=arc(pair.cutter),w=analytic.witnesses.find(x=>x.insideBoth);
const unwrap=r=>{if(!r.isOk())throw r[0];return r[0];};
const p=unwrap(g.segment_point(a,w.left_t)),q=unwrap(g.segment_point(b,w.right_t));
const queries=[];
for(const reverse of [false,true])for(const max_depth of [48,96]){
 const r=ix.segment_with(...(reverse?[b,a]:[a,b]),Object.assign(ix.default_options(),{max_depth}));
 queries.push({reverse,max_depth,result:r.isOk()?[...r[0]]:{error:r[0]}});
}
const cropped=unwrap(g.segment_between(b,.49,.51));
const r=ix.segment(a,cropped);
const report={witness:w,leftEvaluated:p,rightEvaluated:q,separation:Math.hypot(p.x-q.x,p.y-q.y),queries,croppedQuarterResult:r.isOk()?[...r[0]]:{error:r[0]}};
fs.writeFileSync(new URL('remaining-continuity-4295-witness.json',import.meta.url),JSON.stringify(report,null,2)+'\n');
console.log(JSON.stringify(report));
