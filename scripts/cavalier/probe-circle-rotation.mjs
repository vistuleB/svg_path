// Diagnostic candidate only: compute circular centers before rotating coordinates.
import fs from 'node:fs';
import * as e from '../../test_portable/build/dev/javascript/svg_path/svg_path/ellipse.mjs';
const inputs=JSON.parse(fs.readFileSync(new URL('./semicircle-native.json',import.meta.url)));
const rows=[];
const dist=(a,b)=>Math.hypot(a.x-b.x,a.y-b.y);
for(const input of inputs)for(const large of [false,true])for(const sweep of [false,true]) {
 const p=a=>new e.EllipsePoint(...a);
 const source=phi=>new e.EndpointArcData(p(input.start),new e.EllipsePoint(input.radius,input.radius),phi,large,sweep,p(input.end));
 const reference=e.endpoint_to_center(source(0))[0];
 for(const phi of [0,17,37,73,90,137,359]) {
  const actual=e.endpoint_to_center(source(phi))[0];
  let angle=((reference.start_angle-phi+180)%360+360)%360-180;
  const candidate=new e.CenterArcData(reference.center,reference.radius,phi,angle,reference.delta_angle);
  const sampleError=arc=>Math.max(...[0,.25,.5,.75,1].map(t=>dist(e.arc_point(arc,t),e.arc_point(reference,t))));
  const boundError=arc=>{const a=e.arc_bounding_box(arc),b=e.arc_bounding_box(reference);return Math.max(Math.abs(a.min.x-b.min.x),Math.abs(a.min.y-b.min.y),Math.abs(a.max.x-b.max.x),Math.abs(a.max.y-b.max.y));};
  rows.push({id:input.id,large,sweep,phi,reference:reference.center,actual:actual.center,candidate:candidate.center,baselineCenterError:dist(actual.center,reference.center),candidateCenterError:dist(candidate.center,reference.center),baselineSampleError:sampleError(actual),candidateSampleError:sampleError(candidate),baselineBoundsError:boundError(actual),candidateBoundsError:boundError(candidate)});
 }
}
console.log(JSON.stringify(rows,null,2));
