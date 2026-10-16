import fs from 'node:fs';
import * as g from '../../test_portable/build/dev/javascript/svg_path/svg_path.mjs';
import * as ix from '../../test_portable/build/dev/javascript/svg_path/svg_path/intersections.mjs';
import * as ov from '../../test_portable/build/dev/javascript/svg_path/svg_path/overlaps.mjs';
const pair=JSON.parse(fs.readFileSync(new URL('remaining-fl006-experiment.json',import.meta.url))).arrangementShortPair;
const arc=s=>new g.Arc(new g.Point(s.start.x,s.start.y),new g.Point(s.radius.x,s.radius.y),s.x_axis_rotation,s.large_arc,s.sweep,new g.Point(s.end.x,s.end.y));
const a=arc(pair.left),b=arc(pair.right);
const unwrap=r=>{if(!r.isOk())throw r[0];return r[0];};
const query=r=>r.isOk()?{ok:true,values:[...r[0]]}:{ok:false,error:r[0].constructor.name};
const rows=[];
for(const tolerance of [1e-6,5e-7,1e-7,5e-8,1e-8,1e-9]){
 const overlaps=ov.segment_with(a,b,tolerance);
 const details=overlaps.isOk()?[...overlaps[0]].map(o=>{
  let maxDistance=0,at=0;
  for(let i=0;i<=1000;i++){const t=i/1000,p=unwrap(g.segment_point(a,o.left_from+t*(o.left_to-o.left_from))),q=unwrap(g.segment_point(b,o.right_from+t*(o.right_to-o.right_from))),d=Math.hypot(p.x-q.x,p.y-q.y);if(d>maxDistance){maxDistance=d;at=t;}}
  return {overlap:o,maxDistance,at};
 }):[];
 rows.push({tolerance,overlaps:query(overlaps),details,intersections:query(ix.segment_with(a,b,Object.assign(ix.default_options(),{tolerance}))),withoutOverlap:query(ix.segment_without_overlap_precheck_with(a,b,Object.assign(ix.default_options(),{tolerance})))});
}
fs.writeFileSync(new URL('remaining-fl006-short-overlap.json',import.meta.url),JSON.stringify({pair,rows},null,2)+'\n');
console.log(JSON.stringify(rows,null,2));
