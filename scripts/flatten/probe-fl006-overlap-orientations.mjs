import fs from 'node:fs';
import * as g from '/tmp/fl006-overlap-runtime/svg_path/svg_path.mjs';
import * as ix from '/tmp/fl006-overlap-runtime/svg_path/svg_path/intersections.mjs';
import * as ov from '/tmp/fl006-overlap-runtime/svg_path/svg_path/overlaps.mjs';
const pair=JSON.parse(fs.readFileSync(new URL('remaining-fl006-experiment.json',import.meta.url))).arrangementShortPair;
const arc=s=>new g.Arc(new g.Point(s.start.x,s.start.y),new g.Point(s.radius.x,s.radius.y),s.x_axis_rotation,s.large_arc,s.sweep,new g.Point(s.end.x,s.end.y));
const a=arc(pair.left),b=arc(pair.right),rows=[];
for(const reverseLeft of [false,true])for(const reverseRight of [false,true])for(const swapped of [false,true]){
 const left=reverseLeft?g.segment_reverse(a):a,right=reverseRight?g.segment_reverse(b):b,args=swapped?[right,left]:[left,right];
 const hits=ix.segment_with(...args,Object.assign(ix.default_options(),{tolerance:5e-7})),overlaps=ov.segment_with(...args,5e-7);
 rows.push({reverseLeft,reverseRight,swapped,hits:hits.isOk()?[...hits[0]]:{error:hits[0].constructor.name},overlaps:overlaps.isOk()?[...overlaps[0]]:{error:overlaps[0].constructor.name}});
}
const controls=[];
for(const reversed of [false,true]){
 const r=ov.segment_with(a,reversed?g.segment_reverse(a):a,5e-7);
 controls.push({reversed,overlaps:r.isOk()?[...r[0]]:{error:r[0].constructor.name}});
}
fs.writeFileSync(new URL('remaining-fl006-overlap-orientations.json',import.meta.url),JSON.stringify({rows,controls},null,2)+'\n');
console.log(rows.map(r=>({reverseLeft:r.reverseLeft,reverseRight:r.reverseRight,swapped:r.swapped,hits:r.hits.length,overlaps:r.overlaps.length})),controls);
